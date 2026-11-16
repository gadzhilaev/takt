"""Scan open tasks and send due-soon / overdue reminders once each."""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.config import Settings, get_settings
from app.db.session import AsyncSessionLocal
from app.models.task import Task, TaskAssignee
from app.models.team import TaskStatus
from app.services import notify_service

logger = logging.getLogger(__name__)


async def process_due_reminders(
    *,
    settings: Settings | None = None,
    now: datetime | None = None,
) -> dict[str, int]:
    settings = settings or get_settings()
    now = now or datetime.now(UTC)
    if now.tzinfo is None:
        now = now.replace(tzinfo=UTC)

    soon_hours = max(1, int(settings.DUE_SOON_HOURS))
    soon_until = now + timedelta(hours=soon_hours)
    sent_soon = 0
    sent_overdue = 0

    async with AsyncSessionLocal() as db:
        q = (
            select(Task)
            .join(TaskStatus, Task.status_id == TaskStatus.id)
            .where(
                Task.due_date.isnot(None),
                Task.deleted_at.is_(None),
                Task.archived_at.is_(None),
                Task.closed_at.is_(None),
                TaskStatus.is_done.is_(False),
            )
            .options(
                selectinload(Task.assignees).selectinload(TaskAssignee.user),
            )
        )
        result = await db.execute(q)
        tasks = list(result.scalars().unique().all())

        for task in tasks:
            due = task.due_date
            if due is None:
                continue
            if due.tzinfo is None:
                due = due.replace(tzinfo=UTC)

            if due <= now:
                if task.overdue_notified_at is None:
                    await notify_service.notify_task_due(
                        db,
                        task=task,
                        kind="task_overdue",
                        subject="Срок просрочен",
                        push_title="Срок просрочен",
                        settings=settings,
                    )
                    task.overdue_notified_at = now
                    # Also mark soon so we don't send a late "soon" after overdue.
                    if task.due_soon_notified_at is None:
                        task.due_soon_notified_at = now
                    sent_overdue += 1
                continue

            if task.due_soon_notified_at is None and due <= soon_until:
                hours_left = max(1, int((due - now).total_seconds() // 3600) or 1)
                # Prefer exact remaining hours when < soon_hours, else the threshold.
                if hours_left >= soon_hours:
                    subject = f"Срок через {soon_hours} ч."
                else:
                    subject = f"Срок через {hours_left} ч."
                await notify_service.notify_task_due(
                    db,
                    task=task,
                    kind="task_due_soon",
                    subject=subject,
                    push_title="Скоро срок",
                    settings=settings,
                )
                task.due_soon_notified_at = now
                sent_soon += 1

        if sent_soon or sent_overdue:
            await db.commit()
        else:
            await db.rollback()

    return {"due_soon": sent_soon, "overdue": sent_overdue}


async def run_due_pass(settings: Settings | None = None) -> dict[str, int]:
    """One iteration of the background loop: reminders + auto urgency.

    Each step gets its own session from ``AsyncSessionLocal`` and is isolated:
    a failure in one step is logged and does not skip the other.
    """
    settings = settings or get_settings()
    result = {"due_soon": 0, "overdue": 0, "urgency_bumped": 0}
    try:
        counts = await process_due_reminders(settings=settings)
        result["due_soon"] = counts["due_soon"]
        result["overdue"] = counts["overdue"]
        if counts["due_soon"] or counts["overdue"]:
            logger.info(
                "due reminders: soon=%s overdue=%s",
                counts["due_soon"],
                counts["overdue"],
            )
    except Exception:
        logger.exception("due reminder pass failed")
    try:
        from app.services.due_urgency_service import apply_auto_urgency

        async with AsyncSessionLocal() as db:
            # apply_auto_urgency commits (or rolls back) on its own.
            result["urgency_bumped"] = await apply_auto_urgency(db)
        if result["urgency_bumped"]:
            logger.info("auto urgency escalated: %s", result["urgency_bumped"])
    except Exception:
        logger.exception("auto urgency pass failed")
    logger.info(
        "due pass ok: soon=%s overdue=%s urgency=%s",
        result["due_soon"],
        result["overdue"],
        result["urgency_bumped"],
    )
    return result


async def due_reminder_loop(stop: asyncio.Event) -> None:
    settings = get_settings()
    if not settings.DUE_REMINDER_ENABLED or settings.DUE_REMINDER_INTERVAL_SECONDS <= 0:
        return
    interval = max(30, int(settings.DUE_REMINDER_INTERVAL_SECONDS))
    while not stop.is_set():
        await run_due_pass(settings)
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except TimeoutError:
            continue
