import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_admin, verify_csrf
from app.api.serializers import status_to_out
from app.db.session import get_db
from app.models.project import ProjectMemberRole
from app.models.task import Task
from app.models.team import TaskStatus, TeamSettings
from app.models.user import User, UserRole
from app.services import project_service

router = APIRouter(prefix="/settings", tags=["settings"])


async def _ensure_column_access(
    db: AsyncSession, user: User, project_id: uuid.UUID | None
) -> None:
    """Project columns: any member+. Global statuses: system admin only."""
    if project_id is None:
        if user.role != UserRole.admin:
            raise HTTPException(
                status_code=403,
                detail={"error": {"code": "forbidden", "message": "Нет прав"}},
            )
        return
    try:
        await project_service.ensure_project_access(
            db, user, project_id, min_role=ProjectMemberRole.member
        )
    except PermissionError:
        raise HTTPException(
            status_code=403,
            detail={"error": {"code": "forbidden", "message": "Нет прав на столбцы проекта"}},
        )


@router.get("/team")
async def get_team(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    team = await db.get(TeamSettings, 1)
    logo_url = f"/api/v1/files/logo" if team and team.logo_path else None
    return {
        "team_name": team.team_name if team else "Моя команда",
        "logo_url": logo_url,
    }


@router.patch("/team", dependencies=[Depends(verify_csrf)])
async def update_team(
    body: dict,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    team = await db.get(TeamSettings, 1)
    if not team:
        team = TeamSettings(id=1)
        db.add(team)
    if "team_name" in body:
        team.team_name = body["team_name"]
    await db.commit()
    return {"team_name": team.team_name}


@router.get("/statuses")
async def list_statuses(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    project_id: uuid.UUID | None = None,
):
    q = select(TaskStatus).order_by(TaskStatus.position)
    if project_id:
        q = q.where(TaskStatus.project_id == project_id)
    rows = (await db.execute(q)).scalars().all()
    return {"items": [status_to_out(s) for s in rows]}


@router.post("/statuses", dependencies=[Depends(verify_csrf)])
async def create_status(
    body: dict,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    project_id = uuid.UUID(str(body["project_id"])) if body.get("project_id") else None
    await _ensure_column_access(db, user, project_id)
    q = select(TaskStatus.position).order_by(TaskStatus.position.desc())
    if project_id:
        q = q.where(TaskStatus.project_id == project_id)
    max_pos = await db.scalar(q)
    status = TaskStatus(
        name=body["name"],
        color=body.get("color", "#94a3b8"),
        position=float(body.get("position", (max_pos or 0) + 1)),
        is_done=bool(body.get("is_done", False)),
        project_id=project_id,
    )
    db.add(status)
    await db.commit()
    return {"status": status_to_out(status)}


@router.patch("/statuses/{status_id}", dependencies=[Depends(verify_csrf)])
async def update_status(
    status_id: uuid.UUID,
    body: dict,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    status = await db.get(TaskStatus, status_id)
    if not status:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    await _ensure_column_access(db, user, status.project_id)
    for key in ("name", "color", "position", "is_done"):
        if key in body:
            setattr(status, key, body[key] if key != "position" else float(body[key]))
    await db.commit()
    return {"status": status_to_out(status)}


@router.delete("/statuses/{status_id}", dependencies=[Depends(verify_csrf)])
async def delete_status(
    status_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    move_to_status_id: uuid.UUID | None = None,
):
    status = await db.get(TaskStatus, status_id)
    if not status:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    await _ensure_column_access(db, user, status.project_id)

    if status.project_id is not None:
        col_count = await db.scalar(
            select(func.count()).select_from(TaskStatus).where(TaskStatus.project_id == status.project_id)
        )
        if (col_count or 0) <= 1:
            raise HTTPException(
                status_code=400,
                detail={
                    "error": {
                        "code": "last_column",
                        "message": "Нельзя удалить последний столбец проекта",
                    }
                },
            )

    task_count = await db.scalar(
        select(func.count()).select_from(Task).where(
            Task.status_id == status_id, Task.deleted_at.is_(None)
        )
    ) or 0

    if task_count > 0:
        if not move_to_status_id:
            raise HTTPException(
                status_code=400,
                detail={
                    "error": {
                        "code": "in_use",
                        "message": "В столбце есть задачи — укажите move_to_status_id",
                        "task_count": task_count,
                    }
                },
            )
        if move_to_status_id == status_id:
            raise HTTPException(
                status_code=400,
                detail={"error": {"code": "same_column", "message": "Целевой столбец совпадает с удаляемым"}},
            )
        target = await db.get(TaskStatus, move_to_status_id)
        if not target:
            raise HTTPException(
                status_code=400,
                detail={"error": {"code": "invalid_target", "message": "Целевой столбец не найден"}},
            )
        if status.project_id and target.project_id != status.project_id:
            raise HTTPException(
                status_code=400,
                detail={"error": {"code": "project_mismatch", "message": "Столбцы из разных проектов"}},
            )
        max_pos = await db.scalar(
            select(func.max(Task.position)).where(
                Task.status_id == move_to_status_id, Task.deleted_at.is_(None)
            )
        )
        base = float(max_pos or 0)
        tasks = (
            await db.execute(
                select(Task)
                .where(Task.status_id == status_id, Task.deleted_at.is_(None))
                .order_by(Task.position)
            )
        ).scalars().all()
        for i, t in enumerate(tasks, start=1):
            t.status_id = move_to_status_id
            t.position = base + i * 1024
            if target.is_done and t.closed_at is None:
                from datetime import UTC, datetime

                t.closed_at = datetime.now(UTC)
            if not target.is_done:
                t.closed_at = None

    await db.delete(status)
    await db.commit()
    return {"ok": True, "moved": task_count}
