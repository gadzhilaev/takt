import json
import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, verify_csrf
from app.api.serializers import task_to_out, user_brief
from app.db.session import get_db
from app.models.task import (
    ActivityLog,
    ChecklistItem,
    Comment,
    Task,
    TaskAssignee,
    TaskLabel,
    TaskPriority,
)
from app.models.user import User
from app.schemas.task import (
    ChecklistCreate,
    ChecklistUpdate,
    CommentCreate,
    CommentOut,
    TaskCreate,
    TaskMove,
    TaskUpdate,
)
from app.models.project import ProjectMemberRole
from app.services import notify_service, task_service
from app.services.websocket_hub import ws_manager

router = APIRouter(prefix="/tasks", tags=["tasks"])


async def _user_names(db: AsyncSession, user_ids: list[uuid.UUID]) -> dict[uuid.UUID, str]:
    if not user_ids:
        return {}
    rows = (await db.execute(select(User.id, User.name).where(User.id.in_(user_ids)))).all()
    return {row[0]: row[1] for row in rows}


async def _ensure_assignees_in_project(
    db: AsyncSession, project_id: uuid.UUID, assignee_ids: list[uuid.UUID]
) -> None:
    from app.models.project import ProjectMember

    if not assignee_ids:
        return
    rows = (
        await db.execute(
            select(ProjectMember.user_id).where(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id.in_(assignee_ids),
            )
        )
    ).scalars().all()
    allowed = set(rows)
    missing = [uid for uid in assignee_ids if uid not in allowed]
    if missing:
        raise HTTPException(
            status_code=400,
            detail={
                "error": {
                    "code": "assignee_not_member",
                    "message": "Исполнителем может быть только участник проекта",
                }
            },
        )


async def _task_out(db: AsyncSession, task: Task):
    comments = await task_service.comment_counts_for(db, [task.id])
    substats = await task_service.subtask_stats_for(db, [task.id])
    total_sub, done_sub = substats.get(task.id, (0, 0))
    return task_to_out(
        task,
        comment_count=comments.get(task.id, 0),
        subtask_total=total_sub,
        subtask_done=done_sub,
    )


@router.get("")
async def list_tasks_route(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    search: str | None = None,
    status_id: uuid.UUID | None = None,
    priority: TaskPriority | None = None,
    assignee_id: uuid.UUID | None = None,
    label_id: uuid.UUID | None = None,
    project_id: uuid.UUID | None = None,
    parent_id: uuid.UUID | None = None,
    mine: bool = False,
    include_archived: bool = False,
    page: int = 1,
    page_size: int = 500,
):
    from app.services import project_service

    if project_id:
        try:
            await project_service.ensure_project_access(db, user, project_id)
        except PermissionError:
            raise HTTPException(
                status_code=403,
                detail={"error": {"code": "forbidden", "message": "Нет доступа к проекту"}},
            )
    tasks, total = await task_service.list_tasks(
        db,
        search=search,
        status_id=status_id,
        priority=priority,
        assignee_id=assignee_id,
        label_id=label_id,
        project_id=project_id,
        parent_id=parent_id,
        roots_only=parent_id is None,
        include_archived=include_archived,
        mine_user_id=user.id if mine else None,
        page=page,
        page_size=min(page_size, 1000),
    )
    ids = [t.id for t in tasks]
    comments = await task_service.comment_counts_for(db, ids)
    substats = await task_service.subtask_stats_for(db, ids)
    items = []
    for t in tasks:
        total_sub, done_sub = substats.get(t.id, (0, 0))
        items.append(
            task_to_out(
                t,
                comment_count=comments.get(t.id, 0),
                subtask_total=total_sub,
                subtask_done=done_sub,
            )
        )
    return {"items": items, "total": total, "page": page, "page_size": page_size}


@router.post("", dependencies=[Depends(verify_csrf)])
async def create_task(
    body: TaskCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from app.services import project_service

    status = await task_service.get_status(db, body.status_id)
    if not status:
        raise HTTPException(status_code=400, detail={"error": {"code": "invalid_status", "message": "Статус не найден"}})
    project_id = body.project_id or status.project_id
    if not project_id:
        raise HTTPException(status_code=400, detail={"error": {"code": "no_project", "message": "Укажите проект"}})
    try:
        await project_service.ensure_project_access(
            db, user, project_id, min_role=ProjectMemberRole.member
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав на создание"}})
    if status.project_id and status.project_id != project_id:
        raise HTTPException(status_code=400, detail={"error": {"code": "status_mismatch", "message": "Статус из другого проекта"}})
    pos = await task_service.next_position(db, body.status_id)
    task = Task(
        title=body.title,
        description=body.description,
        status_id=body.status_id,
        project_id=project_id,
        parent_id=body.parent_id,
        priority=body.priority,
        author_id=user.id,
        due_date=body.due_date,
        position=pos,
    )
    if status.is_done:
        task.closed_at = datetime.now(UTC)
    db.add(task)
    await db.flush()
    if body.assignee_ids:
        await _ensure_assignees_in_project(db, project_id, body.assignee_ids)
    for uid in body.assignee_ids:
        db.add(TaskAssignee(task_id=task.id, user_id=uid))
    for name in body.label_names:
        label = await task_service.get_or_create_label(db, name.strip())
        db.add(TaskLabel(task_id=task.id, label_id=label.id))
    await task_service.log_activity(db, task.id, user.id, "created")
    await db.flush()
    if body.assignee_ids:
        name_map = await _user_names(db, body.assignee_ids)
        await notify_service.notify_assignees(
            db,
            actor=user,
            task=task,
            new_assignee_ids=list(body.assignee_ids),
            all_assignees=[(uid, name_map.get(uid, "Участник")) for uid in body.assignee_ids],
        )
    await db.commit()
    task = await task_service.get_task(db, task.id)
    out = await _task_out(db, task)  # type: ignore[arg-type]
    await ws_manager.broadcast("task.created", {"task": out.model_dump(mode="json")})
    return {"task": out}


@router.get("/{task_id}")
async def get_task_route(
    task_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    task = await task_service.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    return {"task": await _task_out(db, task)}


@router.patch("/{task_id}", dependencies=[Depends(verify_csrf)])
async def update_task(
    task_id: uuid.UUID,
    body: TaskUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    task = await task_service.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    if body.title is not None:
        await task_service.log_activity(db, task.id, user.id, "updated", "title", task.title, body.title)
        task.title = body.title
    if body.description is not None:
        task.description = body.description
    if body.priority is not None:
        await task_service.log_activity(
            db, task.id, user.id, "updated", "priority", task.priority.value, body.priority.value
        )
        task.priority = body.priority
    if body.due_date is not None:
        old = task.due_date.isoformat() if task.due_date else None
        new = body.due_date.isoformat() if body.due_date else None
        await task_service.log_activity(db, task.id, user.id, "updated", "due_date", old, new)
        task.due_date = body.due_date
    if body.position is not None:
        task.position = body.position
    newly_done = False
    if body.status_id is not None:
        status = await task_service.get_status(db, body.status_id)
        if not status:
            raise HTTPException(status_code=400, detail={"error": {"code": "invalid_status", "message": "Статус не найден"}})
        old = str(task.status_id)
        newly_done = await task_service.apply_status_change(db, task, status)
        await task_service.log_activity(db, task.id, user.id, "status_changed", "status_id", old, str(status.id))
    if body.assignee_ids is not None:
        prev_ids = {a.user_id for a in (task.assignees or [])}
        if task.project_id and body.assignee_ids:
            await _ensure_assignees_in_project(db, task.project_id, body.assignee_ids)
        await db.execute(delete(TaskAssignee).where(TaskAssignee.task_id == task.id))
        await db.flush()
        for uid in body.assignee_ids:
            db.add(TaskAssignee(task_id=task.id, user_id=uid))
        await task_service.log_activity(db, task.id, user.id, "assignees_changed")
        new_ids = [uid for uid in body.assignee_ids if uid not in prev_ids]
        if new_ids:
            name_map = await _user_names(db, list(body.assignee_ids))
            await notify_service.notify_assignees(
                db,
                actor=user,
                task=task,
                new_assignee_ids=new_ids,
                all_assignees=[(uid, name_map.get(uid, "Участник")) for uid in body.assignee_ids],
            )
    if body.label_names is not None:
        await db.execute(delete(TaskLabel).where(TaskLabel.task_id == task.id))
        await db.flush()
        for name in body.label_names:
            label = await task_service.get_or_create_label(db, name.strip())
            db.add(TaskLabel(task_id=task.id, label_id=label.id))
    if body.archived is True and task.archived_at is None:
        task.archived_at = datetime.now(UTC)
        await task_service.log_activity(db, task.id, user.id, "archived")
    if body.archived is False and task.archived_at is not None:
        task.archived_at = None
        await task_service.log_activity(db, task.id, user.id, "unarchived")
    if newly_done:
        await notify_service.notify_task_completed(db, actor=user, task=task)
    await db.commit()
    task = await task_service.get_task(db, task.id)
    out = await _task_out(db, task)  # type: ignore[arg-type]
    await ws_manager.broadcast("task.updated", {"task": out.model_dump(mode="json")})
    return {"task": out}


@router.post("/{task_id}/move", dependencies=[Depends(verify_csrf)])
async def move_task(
    task_id: uuid.UUID,
    body: TaskMove,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    task = await task_service.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    status = await task_service.get_status(db, body.status_id)
    if not status:
        raise HTTPException(status_code=400, detail={"error": {"code": "invalid_status", "message": "Статус не найден"}})
    newly_done = await task_service.apply_status_change(db, task, status)
    task.position = body.position
    await task_service.log_activity(db, task.id, user.id, "moved", "status_id", None, str(status.id))
    if newly_done:
        await notify_service.notify_task_completed(db, actor=user, task=task)
    await db.commit()
    task = await task_service.get_task(db, task.id)
    out = await _task_out(db, task)  # type: ignore[arg-type]
    await ws_manager.broadcast("task.moved", {"task": out.model_dump(mode="json")})
    return {"task": out}


@router.delete("/{task_id}", dependencies=[Depends(verify_csrf)])
async def delete_task(
    task_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    task = await task_service.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    if not task_service.can_delete_task(user, task):
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Можно удалять только свои задачи"}})
    await task_service.soft_delete_task(db, task)
    await db.commit()
    await ws_manager.broadcast("task.deleted", {"task_id": str(task_id)})
    return {"ok": True}


@router.post("/{task_id}/restore", dependencies=[Depends(verify_csrf)])
async def restore_task(
    task_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    q = select(Task).where(Task.id == task_id)
    task = (await db.execute(q)).scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    if not task_service.can_delete_task(user, task):
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Недостаточно прав"}})
    task.deleted_at = None
    task.archived_at = None
    await task_service.log_activity(db, task.id, user.id, "restored")
    await db.commit()
    task = await task_service.get_task(db, task.id)
    out = await _task_out(db, task)  # type: ignore[arg-type]
    await ws_manager.broadcast("task.updated", {"task": out.model_dump(mode="json")})
    return {"task": out}


@router.post("/{task_id}/duplicate", dependencies=[Depends(verify_csrf)])
async def duplicate_task(
    task_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    source = await task_service.get_task(db, task_id)
    if not source:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    pos = await task_service.next_position(db, source.status_id)
    clone = Task(
        title=f"{source.title} (копия)",
        description=source.description,
        status_id=source.status_id,
        project_id=source.project_id,
        parent_id=source.parent_id,
        priority=source.priority,
        author_id=user.id,
        due_date=source.due_date,
        position=pos,
    )
    db.add(clone)
    await db.flush()
    for a in source.assignees or []:
        db.add(TaskAssignee(task_id=clone.id, user_id=a.user_id))
    for tl in source.labels or []:
        db.add(TaskLabel(task_id=clone.id, label_id=tl.label_id))
    for item in source.checklist_items or []:
        db.add(
            ChecklistItem(
                task_id=clone.id,
                title=item.title,
                is_done=False,
                position=item.position,
            )
        )
    await task_service.log_activity(db, clone.id, user.id, "created")
    await db.commit()
    task = await task_service.get_task(db, clone.id)
    out = await _task_out(db, task)  # type: ignore[arg-type]
    await ws_manager.broadcast("task.created", {"task": out.model_dump(mode="json")})
    return {"task": out}


@router.get("/{task_id}/comments")
async def list_comments(
    task_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    q = (
        select(Comment)
        .options(selectinload(Comment.author))
        .where(Comment.task_id == task_id)
        .order_by(Comment.created_at.asc())
    )
    comments = (await db.execute(q)).scalars().all()
    items = []
    for c in comments:
        mentions = json.loads(c.mentions) if c.mentions else []
        items.append(
            CommentOut(
                id=str(c.id),
                body=c.body,
                author=user_brief(c.author),
                created_at=c.created_at,
                mentions=mentions,
            )
        )
    return {"items": items}


@router.post("/{task_id}/comments", dependencies=[Depends(verify_csrf)])
async def add_comment(
    task_id: uuid.UUID,
    body: CommentCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    task = await db.get(Task, task_id)
    if not task or task.deleted_at:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Задача не найдена"}})
    comment = Comment(
        task_id=task_id,
        author_id=user.id,
        body=body.body,
        mentions=json.dumps([str(x) for x in body.mention_user_ids]),
    )
    db.add(comment)
    from app.api.v1.notifications import notify_users

    mention_ids = list(body.mention_user_ids)
    await notify_users(
        db,
        user_ids=mention_ids,
        actor_id=user.id,
        kind="mention",
        title=f"Вас упомянули в «{task.title}»",
        body=body.body[:200],
        task_id=task_id,
        project_id=task.project_id,
    )
    await db.commit()
    await db.refresh(comment, ["author"])
    out = CommentOut(
        id=str(comment.id),
        body=comment.body,
        author=user_brief(comment.author),
        created_at=comment.created_at,
        mentions=[str(x) for x in body.mention_user_ids],
    )
    await ws_manager.broadcast("comment.added", {"task_id": str(task_id), "comment": out.model_dump(mode="json")})
    return {"comment": out}


@router.get("/{task_id}/activity")
async def activity(
    task_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    q = (
        select(ActivityLog)
        .options(selectinload(ActivityLog.user))
        .where(ActivityLog.task_id == task_id)
        .order_by(ActivityLog.created_at.desc())
    )
    logs = (await db.execute(q)).scalars().all()
    return {
        "items": [
            {
                "id": str(l.id),
                "action": l.action,
                "field": l.field,
                "old_value": l.old_value,
                "new_value": l.new_value,
                "user": user_brief(l.user),
                "created_at": l.created_at,
            }
            for l in logs
        ]
    }


@router.post("/{task_id}/checklist", dependencies=[Depends(verify_csrf)])
async def add_checklist(
    task_id: uuid.UUID,
    body: ChecklistCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    max_pos = await db.scalar(
        select(ChecklistItem.position).where(ChecklistItem.task_id == task_id).order_by(ChecklistItem.position.desc())
    )
    item = ChecklistItem(task_id=task_id, title=body.title, position=(max_pos or 0) + 1)
    db.add(item)
    await db.commit()
    return {"item": {"id": str(item.id), "title": item.title, "is_done": item.is_done, "position": item.position}}


@router.patch("/{task_id}/checklist/{item_id}", dependencies=[Depends(verify_csrf)])
async def update_checklist(
    task_id: uuid.UUID,
    item_id: uuid.UUID,
    body: ChecklistUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await db.get(ChecklistItem, item_id)
    if not item or item.task_id != task_id:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}})
    if body.title is not None:
        item.title = body.title
    if body.is_done is not None:
        item.is_done = body.is_done
    if body.position is not None:
        item.position = body.position
    await db.commit()
    return {"item": {"id": str(item.id), "title": item.title, "is_done": item.is_done, "position": item.position}}
