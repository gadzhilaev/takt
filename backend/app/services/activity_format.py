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

# Column / board moves only — used by clients that hide other noise.
COLUMN_MOVE_ACTIONS = frozenset({"moved", "status_changed"})


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
    """Always return Russian copy — never raw English action codes."""
    key = (action or "").strip().lower()
    if key == "created":
        return "создал(а) задачу"
    if key in ("moved", "status_changed") or field == "status_id":
        if old_label and new_label:
            return f"перенёс(ла) из «{old_label}» в «{new_label}»"
        if new_label:
            return f"перенёс(ла) в «{new_label}»"
        return "изменил(а) столбец"
    if key == "updated":
        if field == "title":
            if old_label and new_label:
                return f"изменил(а) название: «{old_label}» → «{new_label}»"
            return "изменил(а) название"
        if field == "priority":
            if old_label and new_label:
                return f"изменил(а) срочность: {old_label} → {new_label}"
            return "изменил(а) срочность"
        if field == "due_date":
            return "изменил(а) срок"
        if field == "description":
            return "изменил(а) описание"
        return "обновил(а) задачу"
    if key in ("assignees_changed", "assignee_changed"):
        return "изменил(а) исполнителей"
    if key == "archived":
        return "архивировал(а) задачу"
    if key == "unarchived":
        return "вернул(а) задачу из архива"
    if key == "restored":
        return "восстановил(а) задачу"
    if key in ("attachment_added", "attachment_uploaded"):
        if new_label:
            return f"прикрепил(а) файл «{new_label}»"
        return "прикрепил(а) файл"
    if key in ("attachment_removed", "attachment_deleted"):
        if old_label:
            return f"удалил(а) файл «{old_label}»"
        return "удалил(а) файл"
    return "обновил(а) задачу"


def is_column_move_action(action: str | None, field: str | None = None) -> bool:
    key = (action or "").strip().lower()
    return key in COLUMN_MOVE_ACTIONS or field == "status_id"
