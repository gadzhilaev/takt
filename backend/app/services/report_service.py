import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.task import ActivityLog, Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User


async def report_metrics(
    db: AsyncSession,
    start: datetime,
    end: datetime,
    user_ids: list[uuid.UUID] | None = None,
) -> dict:
    now = datetime.now(UTC)
    base = select(Task).where(Task.deleted_at.is_(None))
    if user_ids:
        base = base.join(TaskAssignee).where(TaskAssignee.user_id.in_(user_ids))

    created = await db.scalar(
        select(func.count())
        .select_from(Task)
        .where(
            Task.deleted_at.is_(None),
            Task.created_at >= start,
            Task.created_at <= end,
            *(
                [Task.id.in_(select(TaskAssignee.task_id).where(TaskAssignee.user_id.in_(user_ids)))]
                if user_ids
                else []
            ),
        )
    )
    closed = await db.scalar(
        select(func.count())
        .select_from(Task)
        .where(
            Task.deleted_at.is_(None),
            Task.closed_at.isnot(None),
            Task.closed_at >= start,
            Task.closed_at <= end,
        )
    )
    statuses = await db.execute(select(TaskStatus))
    status_map = {s.id: s for s in statuses.scalars().all()}
    in_progress = 0
    for sid, st in status_map.items():
        if not st.is_done:
            cnt = await db.scalar(
                select(func.count())
                .select_from(Task)
                .where(Task.status_id == sid, Task.deleted_at.is_(None))
            )
            in_progress += cnt or 0
    overdue = await db.scalar(
        select(func.count())
        .select_from(Task)
        .where(
            Task.deleted_at.is_(None),
            Task.due_date.isnot(None),
            Task.due_date < now,
            Task.closed_at.is_(None),
        )
    )
    avg_days = await db.scalar(
        select(
            func.avg(
                func.extract("epoch", Task.closed_at - Task.created_at) / 86400.0
            )
        ).where(
            Task.deleted_at.is_(None),
            Task.closed_at.isnot(None),
            Task.closed_at >= start,
            Task.closed_at <= end,
        )
    )
    by_status_q = await db.execute(
        select(Task.status_id, func.count())
        .where(Task.deleted_at.is_(None))
        .group_by(Task.status_id)
    )
    # Aggregate by display name — statuses are per-project with duplicate names.
    by_status_agg: dict[str, int] = {}
    for sid, cnt in by_status_q.all():
        name = status_map[sid].name if sid in status_map else "?"
        by_status_agg[name] = by_status_agg.get(name, 0) + int(cnt)
    by_status = sorted(by_status_agg.items(), key=lambda x: (-x[1], x[0]))
    by_priority_q = await db.execute(
        select(Task.priority, func.count())
        .where(Task.deleted_at.is_(None))
        .group_by(Task.priority)
    )
    by_priority = {p.value: c for p, c in by_priority_q.all()}
    return {
        "created": created or 0,
        "closed": closed or 0,
        "in_progress": in_progress,
        "overdue": overdue or 0,
        "avg_days": (
            round(float(avg_days), 1)
            if avg_days is not None and (closed or 0) > 0
            else None
        ),
        "by_status": by_status,
        "by_priority": by_priority,
    }


async def closed_by_day(
    db: AsyncSession, start: datetime, end: datetime
) -> list[dict]:
    day = func.date_trunc("day", Task.closed_at).label("day")
    rows = await db.execute(
        select(day, func.count())
        .where(
            Task.closed_at.isnot(None),
            Task.closed_at >= start,
            Task.closed_at <= end,
            Task.deleted_at.is_(None),
        )
        .group_by(day)
        .order_by(day)
    )
    return [{"date": d.isoformat() if d else None, "count": c} for d, c in rows.all()]


async def by_employee(db: AsyncSession, start: datetime, end: datetime) -> list[dict]:
    users = (await db.execute(select(User).where(User.is_active.is_(True)))).scalars().all()
    now = datetime.now(UTC)
    result = []
    for u in users:
        assigned = await db.scalar(
            select(func.count())
            .select_from(TaskAssignee)
            .join(Task)
            .where(TaskAssignee.user_id == u.id, Task.deleted_at.is_(None))
        )
        closed = await db.scalar(
            select(func.count())
            .select_from(TaskAssignee)
            .join(Task)
            .where(
                TaskAssignee.user_id == u.id,
                Task.closed_at.isnot(None),
                Task.closed_at >= start,
                Task.closed_at <= end,
            )
        )
        in_prog = await db.scalar(
            select(func.count())
            .select_from(TaskAssignee)
            .join(Task)
            .join(TaskStatus, Task.status_id == TaskStatus.id)
            .where(
                TaskAssignee.user_id == u.id,
                Task.deleted_at.is_(None),
                TaskStatus.is_done.is_(False),
            )
        )
        overdue = await db.scalar(
            select(func.count())
            .select_from(TaskAssignee)
            .join(Task)
            .where(
                TaskAssignee.user_id == u.id,
                Task.due_date.isnot(None),
                Task.due_date < now,
                Task.closed_at.is_(None),
            )
        )
        # % в срок: среди закрытых в периоде задач СО сроком — доля закрытых не позже due_date.
        closed_with_due = await db.scalar(
            select(func.count())
            .select_from(TaskAssignee)
            .join(Task)
            .where(
                TaskAssignee.user_id == u.id,
                Task.closed_at.isnot(None),
                Task.closed_at >= start,
                Task.closed_at <= end,
                Task.due_date.isnot(None),
                Task.deleted_at.is_(None),
            )
        )
        on_time = await db.scalar(
            select(func.count())
            .select_from(TaskAssignee)
            .join(Task)
            .where(
                TaskAssignee.user_id == u.id,
                Task.closed_at.isnot(None),
                Task.closed_at >= start,
                Task.closed_at <= end,
                Task.due_date.isnot(None),
                Task.closed_at <= Task.due_date,
                Task.deleted_at.is_(None),
            )
        )
        closed_total = closed or 0
        due_n = closed_with_due or 0
        pct = round(100.0 * (on_time or 0) / due_n, 1) if due_n else None
        result.append(
            {
                "user_id": str(u.id),
                "name": u.name,
                "assigned": assigned or 0,
                "closed": closed_total,
                "in_progress": in_prog or 0,
                "overdue": overdue or 0,
                "on_time_pct": pct,
            }
        )
    return result


async def recent_completed(db: AsyncSession, limit: int = 20) -> list[dict]:
    q = (
        select(Task)
        .options(selectinload(Task.status), selectinload(Task.assignees).selectinload(TaskAssignee.user))
        .where(Task.closed_at.isnot(None), Task.deleted_at.is_(None))
        .order_by(Task.closed_at.desc())
        .limit(limit)
    )
    tasks = (await db.execute(q)).scalars().all()
    return [
        {
            "id": str(t.id),
            "title": t.title,
            "closed_at": t.closed_at,
            "status": t.status.name if t.status else "",
        }
        for t in tasks
    ]


async def history_for_export(
    db: AsyncSession, start: datetime, end: datetime
) -> list[dict]:
    q = (
        select(ActivityLog)
        .options(selectinload(ActivityLog.task), selectinload(ActivityLog.user))
        .where(ActivityLog.created_at >= start, ActivityLog.created_at <= end)
        .order_by(ActivityLog.created_at.desc())
    )
    logs = (await db.execute(q)).scalars().all()
    return [
        {
            "created_at": log.created_at,
            "task_title": log.task.title if log.task else "",
            "user_name": log.user.name if log.user else "",
            "action": log.action,
            "field": log.field,
            "old_value": log.old_value,
            "new_value": log.new_value,
        }
        for log in logs
    ]


def period_range(preset: str, custom_start: datetime | None, custom_end: datetime | None):
    now = datetime.now(UTC)
    end = now
    if preset == "week":
        start = now - timedelta(days=7)
    elif preset == "month":
        start = now - timedelta(days=30)
    elif preset == "quarter":
        start = now - timedelta(days=90)
    elif preset == "custom" and custom_start and custom_end:
        start, end = custom_start, custom_end
    else:
        start = now - timedelta(days=30)
    return start, end
