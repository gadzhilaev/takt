from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.models.notification import Notification
from app.models.project import Project
from app.models.task import Task
from app.models.user import User
from app.services import fcm_service, push_service
from app.services.ru_names import format_assignment_line, format_completed_line


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
        return f"/app/projects/{project_id}?task={task_id}"
    return f"/app/tasks/{task_id}"


async def notify_assignees(
    db: AsyncSession,
    *,
    actor: User,
    task: Task,
    new_assignee_ids: list[uuid.UUID],
    all_assignees: list[tuple[uuid.UUID, str]],
    settings: Settings | None = None,
) -> None:
    """Notify only newly assigned users (exclude actor). Short card copy."""
    _ = all_assignees
    settings = settings or get_settings()
    recipients = [uid for uid in new_assignee_ids if uid != actor.id]
    if not recipients:
        return

    link = task_deep_link(task.project_id, task.id)
    project_name: str | None = None
    if task.project_id:
        project = await db.get(Project, task.project_id)
        project_name = project.name if project else None

    subject = format_assignment_line(actor_name=actor.name)
    body = subject if not project_name else f"{subject}\nПроект {project_name}"
    card_title = (task.title or "Задача").strip()[:255]
    push_body = f"{card_title}\n{subject}"

    for uid in recipients:
        await create_in_app(
            db,
            user_id=uid,
            actor_id=actor.id,
            kind="task_assigned",
            title=card_title,
            body=body,
            task_id=task.id,
            project_id=task.project_id,
        )
        await push_service.send_push_to_users(
            db,
            settings,
            user_ids=[uid],
            title="Новая задача",
            body=push_body,
            url=link,
            tag=f"assign-{task.id}",
        )
        await fcm_service.send_fcm_to_users(
            db,
            settings,
            user_ids=[uid],
            title="Новая задача",
            body=push_body,
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
    subject = format_completed_line(actor_name=actor.name)
    project_name: str | None = None
    if task.project_id:
        project = await db.get(Project, task.project_id)
        project_name = project.name if project else None
    body = subject if not project_name else f"{subject}\nПроект {project_name}"
    card_title = (task.title or "Задача").strip()[:255]
    await create_in_app(
        db,
        user_id=task.author_id,
        actor_id=actor.id,
        kind="task_completed",
        title=card_title,
        body=body,
        task_id=task.id,
        project_id=task.project_id,
    )
    link = task_deep_link(task.project_id, task.id)
    push_body = f"{card_title}\n{subject}"
    await push_service.send_push_to_users(
        db,
        settings,
        user_ids=[task.author_id],
        title="Задача выполнена",
        body=push_body,
        url=link,
        tag=f"done-{task.id}",
    )
    await fcm_service.send_fcm_to_users(
        db,
        settings,
        user_ids=[task.author_id],
        title="Задача выполнена",
        body=push_body,
        data={
            "kind": "task_completed",
            "task_id": str(task.id),
            "project_id": str(task.project_id) if task.project_id else "",
            "url": link,
        },
    )
