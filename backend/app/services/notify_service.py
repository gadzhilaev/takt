from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.models.notification import Notification
from app.models.task import Task
from app.models.user import User
from app.services import fcm_service, push_service
from app.services.ru_names import format_assignment_title, format_completed_title


async def create_in_app(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    actor_id: uuid.UUID | None,
    kind: str,
    title: str,
    body: str | None = None,
    task_id: uuid.UUID | None = None,
    project_id: uuid.UUID | None = None,
) -> Notification:
    n = Notification(
        user_id=user_id,
        actor_id=actor_id,
        kind=kind,
        title=title,
        body=body,
        task_id=task_id,
        project_id=project_id,
        is_read=False,
        created_at=datetime.now(UTC),
    )
    db.add(n)
    return n


def task_deep_link(project_id: uuid.UUID | None, task_id: uuid.UUID) -> str:
    if project_id:
        return f"/projects/{project_id}?task={task_id}"
    return f"/tasks/{task_id}"


async def notify_assignees(
    db: AsyncSession,
    *,
    actor: User,
    task: Task,
    new_assignee_ids: list[uuid.UUID],
    all_assignees: list[tuple[uuid.UUID, str]],
    settings: Settings | None = None,
) -> None:
    """Notify only newly assigned users (exclude actor). Personalized «вам» copy."""
    settings = settings or get_settings()
    recipients = [uid for uid in new_assignee_ids if uid != actor.id]
    if not recipients:
        return

    pairs = [(str(uid), name) for uid, name in all_assignees]
    link = task_deep_link(task.project_id, task.id)
    project_hint = None
    if task.project_id:
        project_hint = f"Проект открывается по ссылке"

    for uid in recipients:
        title = format_assignment_title(
            actor_name=actor.name,
            recipient_id=str(uid),
            assignees=pairs,
            task_title=task.title,
        )
        await create_in_app(
            db,
            user_id=uid,
            actor_id=actor.id,
            kind="task_assigned",
            title=title,
            body=project_hint,
            task_id=task.id,
            project_id=task.project_id,
        )
        await push_service.send_push_to_users(
            db,
            settings,
            user_ids=[uid],
            title="Takt",
            body=title,
            url=link,
            tag=f"assign-{task.id}",
        )
        await fcm_service.send_fcm_to_users(
            db,
            settings,
            user_ids=[uid],
            title="Takt",
            body=title,
            data={
                "kind": "task_assigned",
                "task_id": str(task.id),
                "project_id": str(task.project_id) if task.project_id else "",
                "url": link,
            },
        )


async def notify_task_completed(
    db: AsyncSession,
    *,
    actor: User,
    task: Task,
    settings: Settings | None = None,
) -> None:
    """Notify task author when task first enters an is_done column."""
    if task.author_id == actor.id:
        return
    settings = settings or get_settings()
    title = format_completed_title(actor_name=actor.name, task_title=task.title)
    body = "Задача перенесена в завершённый столбец"
    await create_in_app(
        db,
        user_id=task.author_id,
        actor_id=actor.id,
        kind="task_completed",
        title=title,
        body=body,
        task_id=task.id,
        project_id=task.project_id,
    )
    link = task_deep_link(task.project_id, task.id)
    await push_service.send_push_to_users(
        db,
        settings,
        user_ids=[task.author_id],
        title="Takt",
        body=title,
        url=link,
        tag=f"done-{task.id}",
    )
    await fcm_service.send_fcm_to_users(
        db,
        settings,
        user_ids=[task.author_id],
        title="Takt",
        body=title,
        data={
            "kind": "task_completed",
            "task_id": str(task.id),
            "project_id": str(task.project_id) if task.project_id else "",
            "url": link,
        },
    )
