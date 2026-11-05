"""Human-readable task activity lines (RU) for API clients."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.team import TaskStatus

PRIORITY_LABELS = {
    "low": "Низкая",
    "medium": "Обычная",
    "high": "Важно",
    "urgent": "Срочно",
}


def _looks_like_uuid(value: str | None) -> bool:
    if not value:
        return False
    try:
        uuid.UUID(value)
        return True
    except (ValueError, TypeError):
        return False


async def resolve_status_labels(
    db: AsyncSession,
    values: list[str | None],
) -> dict[str, str]:
    ids: list[uuid.UUID] = []
    for v in values:
        if v and _looks_like_uuid(v):
            ids.append(uuid.UUID(v))
    if not ids:
        return {}
    rows = (
        await db.execute(select(TaskStatus.id, TaskStatus.name).where(TaskStatus.id.in_(ids)))
    ).all()
    return {str(sid): name for sid, name in rows}


def label_for(
    *,
    field: str | None,
    value: str | None,
    status_names: dict[str, str],
) -> str | None:
    if value is None:
        return None
    if field == "status_id":
        return status_names.get(value, value)
    if field == "priority":
        return PRIORITY_LABELS.get(value, value)
    return value


def activity_summary(
    *,
    action: str,
    field: str | None,
    old_label: str | None,
    new_label: str | None,
) -> str:
    if action == "created":
        return "создал задачу"
    if action in ("moved", "status_changed"):
        if old_label and new_label:
            return f"перенёс из «{old_label}» в «{new_label}»"
        if new_label:
            return f"перенёс в «{new_label}»"
        return "изменил столбец"
    if action == "updated":
        if field == "title":
            if old_label and new_label:
                return f"изменил название: «{old_label}» → «{new_label}»"
            return "изменил название"
        if field == "priority":
            if old_label and new_label:
                return f"изменил срочность: {old_label} → {new_label}"
            return "изменил срочность"
        if field == "due_date":
            return "изменил срок"
        if field == "description":
            return "изменил описание"
        return "обновил задачу"
    if action == "assignees_changed":
        return "изменил исполнителей"
    if action == "archived":
        return "архивировал задачу"
    if action == "unarchived":
        return "вернул задачу из архива"
    if action == "restored":
        return "восстановил задачу"
    if action == "attachment_added":
        if new_label:
            return f"прикрепил файл «{new_label}»"
        return "прикрепил файл"
    if action == "attachment_removed":
        if old_label:
            return f"удалил файл «{old_label}»"
        return "удалил файл"
    return action
