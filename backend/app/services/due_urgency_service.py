"""Escalate task priority from remaining due window (never downgrade).

Thresholds (remaining / original window):
  ≤ 10%  → urgent
  ≤ 35%  → high
  overdue (≤ 0%) → urgent
"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.project import Project
from app.models.task import Task, TaskPriority
from app.models.team import TaskStatus

# remaining_pct threshold → priority (checked high→low urgency)
_THRESHOLDS: list[tuple[float, TaskPriority]] = [
    (0.10, TaskPriority.urgent),
    (0.35, TaskPriority.high),
]

_RANK = {
    TaskPriority.low: 0,
    TaskPriority.medium: 1,
    TaskPriority.high: 2,
    TaskPriority.urgent: 3,
}


def remaining_ratio(due: datetime, basis: datetime, now: datetime) -> float:
    """remaining / window. Overdue → ≤ 0. Degenerate window → 0 if due passed else 1."""
    if due.tzinfo is None:
        due = due.replace(tzinfo=UTC)
    if basis.tzinfo is None:
        basis = basis.replace(tzinfo=UTC)
    if now.tzinfo is None:
        now = now.replace(tzinfo=UTC)
    total = (due - basis).total_seconds()
    rem = (due - now).total_seconds()
    if total <= 0:
        return 0.0 if rem <= 0 else 1.0
    return rem / total


def suggested_priority(due: datetime, basis: datetime, now: datetime) -> TaskPriority | None:
    ratio = remaining_ratio(due, basis, now)
    for threshold, priority in _THRESHOLDS:
        if ratio <= threshold:
            return priority
    return None


def escalate_priority(current: TaskPriority, suggested: TaskPriority | None) -> TaskPriority | None:
    """Return new priority if suggested is strictly higher; else None."""
    if suggested is None:
        return None
    if _RANK[suggested] > _RANK[current]:
        return suggested
    return None


async def apply_auto_urgency(
    db: AsyncSession,
    *,
    now: datetime | None = None,
) -> int:
    """Bump priorities for open tasks in projects with auto_urgency_from_due. Returns count changed."""
    now = now or datetime.now(UTC)
    if now.tzinfo is None:
        now = now.replace(tzinfo=UTC)

    q = (
        select(Task)
        .join(Project, Task.project_id == Project.id)
        .join(TaskStatus, Task.status_id == TaskStatus.id)
        .where(
            Project.auto_urgency_from_due.is_(True),
            Task.due_date.isnot(None),
            Task.due_basis_at.isnot(None),
            Task.deleted_at.is_(None),
            Task.archived_at.is_(None),
            Task.closed_at.is_(None),
            TaskStatus.is_done.is_(False),
        )
        .options(selectinload(Task.status))
    )
    tasks = list((await db.execute(q)).scalars().unique().all())
    changed = 0
    for task in tasks:
        due = task.due_date
        basis = task.due_basis_at
        if due is None or basis is None:
            continue
        suggested = suggested_priority(due, basis, now)
        new_p = escalate_priority(task.priority, suggested)
        if new_p is None:
            continue
        task.priority = new_p
        changed += 1
    if changed:
        await db.commit()
    else:
        await db.rollback()
    return changed


def apply_urgency_to_task(task: Task, *, now: datetime | None = None) -> bool:
    """In-memory escalate for a single task (caller owns commit). Returns True if changed."""
    if task.due_date is None or task.due_basis_at is None:
        return False
    now = now or datetime.now(UTC)
    suggested = suggested_priority(task.due_date, task.due_basis_at, now)
    new_p = escalate_priority(task.priority, suggested)
    if new_p is None:
        return False
    task.priority = new_p
    return True
