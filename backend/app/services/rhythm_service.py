"""Rhythm: once per working day every member gets a check-in on their open tasks.

The answer updates the task itself:

- ``done``        → task moves to the project's «done» column (``is_done``, last by position);
- ``in_progress`` → from the first column to the second; elsewhere the task stays put;
- ``blocked``     → task gets the «Застряла» flag with an optional reason.

The flag is cleared on the next column move or an ``in_progress`` / ``done`` answer.
Every change is written to the task history and goes out as regular notifications;
the API layer broadcasts WS board events after commit.

Logs contain only ids and counts — no names, emails or task titles.
"""

from __future__ import annotations

import asyncio
import hashlib
import logging
import secrets
import uuid
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import Settings, get_settings
from app.db.session import AsyncSessionLocal
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.rhythm import CheckinAnswer, CheckinStatus, RhythmCheckin, RhythmCheckinItem
from app.models.task import Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User
from app.services import notify_service, task_service

logger = logging.getLogger(__name__)

DEFAULT_TIMEZONE = "Europe/Moscow"
DEFAULT_DAYS = [1, 2, 3, 4, 5]
REASON_MAX = 280
CATEGORY_ONE = "TAKT_CHECKIN_ONE"
CATEGORY_MANY = "TAKT_CHECKIN_MANY"
KIND_CHECKIN = "rhythm_checkin"

_PRIORITY_RANK = {
    TaskPriority.urgent: 3,
    TaskPriority.high: 2,
    TaskPriority.medium: 1,
    TaskPriority.low: 0,
}


class RhythmError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


# ---------------------------------------------------------------- schedule


def project_zone(project: Project) -> ZoneInfo:
    try:
        return ZoneInfo(project.rhythm_timezone or DEFAULT_TIMEZONE)
    except (ZoneInfoNotFoundError, ValueError):
        return ZoneInfo(DEFAULT_TIMEZONE)


def is_valid_timezone(name: str) -> bool:
    try:
        ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError):
        return False
    return True


def checkin_day(project: Project, now: datetime, *, window_hours: int = 3) -> date | None:
    """Local day to create check-ins for, or None if it is not check-in time.

    Check-ins are created on enabled weekdays between ``rhythm_time`` and
    ``rhythm_time + window_hours`` in the project's timezone.
    """
    if not project.rhythm_enabled or project.is_archived:
        return None
    if now.tzinfo is None:
        now = now.replace(tzinfo=UTC)
    local = now.astimezone(project_zone(project))
    days = set(project.rhythm_days or DEFAULT_DAYS)
    if local.isoweekday() not in days:
        return None
    start = datetime.combine(local.date(), project.rhythm_time or time(10, 0), local.tzinfo)
    if start <= local < start + timedelta(hours=max(1, window_hours)):
        return local.date()
    return None


def local_today(project: Project, now: datetime | None = None) -> date:
    now = now or datetime.now(UTC)
    return now.astimezone(project_zone(project)).date()


# ---------------------------------------------------------------- task picking


def _task_sort_key(task: Task, now: datetime):
    due = task.due_date
    if due is not None and due.tzinfo is None:
        due = due.replace(tzinfo=UTC)
    overdue = due is not None and due < now
    return (
        0 if overdue else 1,  # overdue first
        due or datetime.max.replace(tzinfo=UTC),  # then nearest deadline
        -_PRIORITY_RANK.get(task.priority, 1),  # then by priority
        task.created_at or now,
    )


async def open_tasks_for(
    db: AsyncSession, project_id: uuid.UUID, user_id: uuid.UUID, *, now: datetime, limit: int
) -> list[Task]:
    rows = (
        await db.execute(
            select(Task)
            .join(TaskAssignee, TaskAssignee.task_id == Task.id)
            .join(TaskStatus, TaskStatus.id == Task.status_id)
            .where(
                Task.project_id == project_id,
                TaskAssignee.user_id == user_id,
                Task.deleted_at.is_(None),
                Task.archived_at.is_(None),
                Task.closed_at.is_(None),
                TaskStatus.is_done.is_(False),
            )
        )
    ).scalars().unique().all()
    return sorted(rows, key=lambda t: _task_sort_key(t, now))[:limit]


# ---------------------------------------------------------------- generation


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@dataclass
class ProjectPassResult:
    created: int = 0
    skipped_old: int = 0
    notified: int = 0
    tokens: dict[uuid.UUID, str] = field(default_factory=dict)


async def generate_project_checkins(
    db: AsyncSession, project: Project, *, now: datetime, settings: Settings
) -> ProjectPassResult:
    """Create today's check-ins in ``project`` (idempotent). Caller commits."""
    result = ProjectPassResult()
    day = checkin_day(project, now, window_hours=settings.RHYTHM_WINDOW_HOURS)
    if day is None:
        return result

    members = (
        await db.execute(
            select(ProjectMember.user_id)
            .join(User, User.id == ProjectMember.user_id)
            .where(
                ProjectMember.project_id == project.id,
                ProjectMember.role.in_([ProjectMemberRole.admin, ProjectMemberRole.member]),
                User.is_active.is_(True),
                User.is_demo.is_(False),
            )
        )
    ).scalars().all()
    existing = set(
        (
            await db.scalars(
                select(RhythmCheckin.user_id).where(
                    RhythmCheckin.project_id == project.id, RhythmCheckin.date == day
                )
            )
        ).all()
    )
    for user_id in members:
        if user_id in existing:
            continue
        created = await create_user_checkin(
            db, project, user_id, day=day, now=now, settings=settings
        )
        if created is None:
            continue
        checkin, token, skipped = created
        result.skipped_old += skipped
        result.created += 1
        result.tokens[checkin.id] = token
    return result


async def create_user_checkin(
    db: AsyncSession,
    project: Project,
    user_id: uuid.UUID,
    *,
    day: date,
    now: datetime,
    settings: Settings,
) -> tuple[RhythmCheckin, str, int] | None:
    """Create one person's check-in for ``day`` (same picking for the loop and manual start).

    Returns (checkin, raw push token, older pending marked skipped) or None when the person
    has no open tasks or the check-in already exists (unique user+project+date).
    Caller commits.
    """
    tasks = await open_tasks_for(
        db, project.id, user_id, now=now, limit=max(1, settings.RHYTHM_MAX_TASKS)
    )
    if not tasks:
        return None
    token = secrets.token_urlsafe(24)
    checkin = RhythmCheckin(
        user_id=user_id,
        project_id=project.id,
        date=day,
        status=CheckinStatus.pending.value,
        created_at=now,
        push_token_hash=_hash_token(token),
    )
    try:
        async with db.begin_nested():  # unique (user, project, date) guards restarts/races
            db.add(checkin)
            await db.flush()
            for pos, task in enumerate(tasks):
                db.add(RhythmCheckinItem(checkin_id=checkin.id, task_id=task.id, position=pos))
            await db.flush()
    except IntegrityError:
        return None
    # Older unanswered check-ins of this person in this project are no longer actionable.
    skipped = await db.execute(
        update(RhythmCheckin)
        .where(
            RhythmCheckin.user_id == user_id,
            RhythmCheckin.project_id == project.id,
            RhythmCheckin.date < day,
            RhythmCheckin.status == CheckinStatus.pending.value,
        )
        .values(status=CheckinStatus.skipped.value)
    )
    return checkin, token, skipped.rowcount or 0


async def start_checkin_now(
    db: AsyncSession,
    *,
    user: User,
    project_id: uuid.UUID,
    settings: Settings | None = None,
    now: datetime | None = None,
) -> RhythmCheckin:
    """Manual «Пройти чек-ин сейчас»: today's check-in without push (existing one is returned).

    Access: member/admin of a project with rhythm enabled. Caller commits.
    """
    settings = settings or get_settings()
    now = now or datetime.now(UTC)
    role = await db.scalar(
        select(ProjectMember.role).where(
            ProjectMember.project_id == project_id, ProjectMember.user_id == user.id
        )
    )
    if role not in (ProjectMemberRole.admin, ProjectMemberRole.member):
        raise RhythmError("forbidden", "Нет доступа к проекту", 403)
    project = await db.get(Project, project_id)
    if project is None or project.is_archived:
        raise RhythmError("not_found", "Проект не найден", 404)
    if not project.rhythm_enabled:
        raise RhythmError("rhythm_off", "Ритм в этом проекте выключен", 409)
    day = local_today(project, now)

    async def existing() -> RhythmCheckin | None:
        return await db.scalar(
            select(RhythmCheckin)
            .options(selectinload(RhythmCheckin.items))
            .where(
                RhythmCheckin.user_id == user.id,
                RhythmCheckin.project_id == project_id,
                RhythmCheckin.date == day,
            )
        )

    found = await existing()
    if found is not None:
        return found
    created = await create_user_checkin(
        db, project, user.id, day=day, now=now, settings=settings
    )
    if created is None:
        found = await existing()  # lost a race with the loop — reuse it
        if found is not None:
            return found
        raise RhythmError("no_open_tasks", "Открытых задач нет — отвечать не на что", 409)
    await db.flush()
    return await existing()  # type: ignore[return-value]


async def startable_project_ids(
    db: AsyncSession, user: User, *, now: datetime | None = None
) -> list[uuid.UUID]:
    """Projects where «Пройти чек-ин сейчас» makes sense: rhythm on, no check-in today,
    the person has open tasks."""
    now = now or datetime.now(UTC)
    rows = (
        await db.execute(
            select(Project)
            .join(ProjectMember, ProjectMember.project_id == Project.id)
            .where(
                ProjectMember.user_id == user.id,
                ProjectMember.role.in_([ProjectMemberRole.admin, ProjectMemberRole.member]),
                Project.rhythm_enabled.is_(True),
                Project.is_archived.is_(False),
            )
        )
    ).scalars().all()
    out: list[uuid.UUID] = []
    for project in rows:
        day = local_today(project, now)
        has = await db.scalar(
            select(RhythmCheckin.id).where(
                RhythmCheckin.user_id == user.id,
                RhythmCheckin.project_id == project.id,
                RhythmCheckin.date == day,
            )
        )
        if has:
            continue
        if await open_tasks_for(db, project.id, user.id, now=now, limit=1):
            out.append(project.id)
    return out


async def notify_checkin(
    db: AsyncSession,
    checkin: RhythmCheckin,
    project: Project,
    *,
    token: str,
    settings: Settings,
) -> None:
    items = (
        await db.execute(
            select(RhythmCheckinItem, Task)
            .join(Task, Task.id == RhythmCheckinItem.task_id)
            .where(RhythmCheckinItem.checkin_id == checkin.id)
            .order_by(RhythmCheckinItem.position)
        )
    ).all()
    if not items:
        return
    n = len(items)
    url = f"/app/checkin/{checkin.id}"
    if n == 1:
        title = "Как дела с задачей?"
        body = (items[0][1].title or "Задача").strip()[:200]
    else:
        title = "Чек-ин на сегодня"
        body = f"{n} {_tasks_word(n)} · {project.name}"
    await notify_service.create_in_app(
        db,
        user_id=checkin.user_id,
        actor_id=None,
        kind=KIND_CHECKIN,
        title=title,
        body=f"{body}\nПроект {project.name}" if n == 1 else body,
        task_id=items[0][1].id if n == 1 else None,
        project_id=project.id,
    )
    from app.services import fcm_service, push_service

    await push_service.send_push_to_users(
        db,
        settings,
        user_ids=[checkin.user_id],
        title=title,
        body=body,
        url=url,
        tag=f"checkin-{checkin.id}",
    )
    data = {
        "kind": KIND_CHECKIN,
        "checkin_id": str(checkin.id),
        "project_id": str(project.id),
        "task_count": str(n),
        "url": url,
        # One-time token: lets the notification action answer without opening the app.
        "action_token": token,
        "action_path": "/api/v1/rhythm/push-answer",
    }
    if n == 1:
        data["task_id"] = str(items[0][1].id)
    await fcm_service.send_fcm_to_users(
        db,
        settings,
        user_ids=[checkin.user_id],
        title=title,
        body=body,
        data=data,
        apns_category=CATEGORY_ONE if n == 1 else CATEGORY_MANY,
        android_data_only=True,
    )
    checkin.notified_at = datetime.now(UTC)


def _tasks_word(n: int) -> str:
    n100, n10 = n % 100, n % 10
    if 11 <= n100 <= 14:
        return "задач"
    if n10 == 1:
        return "задача"
    if 2 <= n10 <= 4:
        return "задачи"
    return "задач"


# ---------------------------------------------------------------- background pass


async def run_rhythm_pass(
    settings: Settings | None = None, now: datetime | None = None
) -> dict[str, int]:
    """One iteration of the rhythm loop. Each project gets its own DB session."""
    settings = settings or get_settings()
    now = now or datetime.now(UTC)
    totals = {"projects": 0, "created": 0, "skipped_old": 0, "failed_projects": 0}
    async with AsyncSessionLocal() as db:
        project_ids = (
            await db.scalars(
                select(Project.id).where(
                    Project.rhythm_enabled.is_(True), Project.is_archived.is_(False)
                )
            )
        ).all()
    for project_id in project_ids:
        totals["projects"] += 1
        try:
            async with AsyncSessionLocal() as db:
                project = await db.get(Project, project_id)
                if project is None:
                    continue
                res = await generate_project_checkins(db, project, now=now, settings=settings)
                if not res.created:
                    await db.rollback()
                    continue
                await db.commit()
                for checkin_id, token in res.tokens.items():
                    checkin = await db.get(RhythmCheckin, checkin_id)
                    if checkin is not None:
                        await notify_checkin(db, checkin, project, token=token, settings=settings)
                await db.commit()
                totals["created"] += res.created
                totals["skipped_old"] += res.skipped_old
        except Exception:
            totals["failed_projects"] += 1
            logger.exception("rhythm pass failed for project %s", project_id)
    logger.info(
        "rhythm pass ok: projects=%s created=%s skipped_old=%s failed=%s",
        totals["projects"],
        totals["created"],
        totals["skipped_old"],
        totals["failed_projects"],
    )
    return totals


async def rhythm_loop(stop: asyncio.Event) -> None:
    settings = get_settings()
    if not settings.RHYTHM_ENABLED or settings.RHYTHM_INTERVAL_SECONDS <= 0:
        return
    interval = max(15, int(settings.RHYTHM_INTERVAL_SECONDS))
    while not stop.is_set():
        await run_rhythm_pass(settings)
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except TimeoutError:
            continue


# ---------------------------------------------------------------- answers


@dataclass
class AppliedAnswer:
    task_id: uuid.UUID
    moved: bool = False
    newly_done: bool = False
    changed: bool = False


async def _project_columns(db: AsyncSession, project_id: uuid.UUID) -> list[TaskStatus]:
    return list(
        (
            await db.scalars(
                select(TaskStatus)
                .where(TaskStatus.project_id == project_id)
                .order_by(TaskStatus.position, TaskStatus.name)
            )
        ).all()
    )


def done_column(columns: list[TaskStatus]) -> TaskStatus | None:
    """The «Готово» column: last is_done column; if none is marked — the last column."""
    done = [c for c in columns if c.is_done]
    if done:
        return done[-1]
    return columns[-1] if columns else None


async def _top_position(db: AsyncSession, status_id: uuid.UUID) -> float:
    from sqlalchemy import func

    low = await db.scalar(
        select(func.min(Task.position)).where(
            Task.status_id == status_id, Task.deleted_at.is_(None)
        )
    )
    return float(low) - 1024 if low is not None else 0.0


async def _move(db: AsyncSession, task: Task, status: TaskStatus, user: User) -> bool:
    old_status_id = task.status_id
    newly_done = await task_service.apply_status_change(db, task, status)
    task.position = await _top_position(db, status.id)
    await task_service.log_activity(
        db, task.id, user.id, "moved", "status_id", str(old_status_id), str(status.id)
    )
    return newly_done


def clear_blocked(task: Task) -> bool:
    if task.blocked_at is None and task.blocked_reason is None:
        return False
    task.blocked_at = None
    task.blocked_reason = None
    task.blocked_by_id = None
    return True


async def apply_answer(
    db: AsyncSession,
    *,
    user: User,
    checkin: RhythmCheckin,
    item: RhythmCheckinItem,
    answer: CheckinAnswer,
    reason: str | None,
    now: datetime | None = None,
) -> AppliedAnswer:
    """Apply one answer. Access must be checked by the caller (``load_checkin_for``)."""
    now = now or datetime.now(UTC)
    task = await db.scalar(
        task_service.task_query_base().where(Task.id == item.task_id)
    )
    if task is None:
        raise RhythmError("task_gone", "Задача удалена", 409)
    if not any(a.user_id == user.id for a in task.assignees or []):
        raise RhythmError("not_assignee", "Вы больше не исполнитель этой задачи", 403)
    reason_clean = (reason or "").strip()[:REASON_MAX] or None

    result = AppliedAnswer(task_id=task.id)
    columns = await _project_columns(db, task.project_id) if task.project_id else []
    if answer == CheckinAnswer.done:
        target = done_column(columns)
        if target is not None and target.id != task.status_id:
            result.newly_done = await _move(db, task, target, user)
            result.moved = True
        result.changed = clear_blocked(task) or result.moved
    elif answer == CheckinAnswer.in_progress:
        open_cols = [c for c in columns if not c.is_done]
        if len(open_cols) >= 2 and task.status_id == open_cols[0].id:
            await _move(db, task, open_cols[1], user)
            result.moved = True
        result.changed = clear_blocked(task) or result.moved
    else:
        task.blocked_at = task.blocked_at or now
        task.blocked_reason = reason_clean
        task.blocked_by_id = user.id
        result.changed = True

    await task_service.log_activity(
        db, task.id, user.id, "checkin", answer.value, None, reason_clean
    )
    item.answer = answer.value
    item.reason = reason_clean if answer == CheckinAnswer.blocked else None
    item.answered_at = now
    if result.newly_done:
        await notify_service.notify_task_completed(db, actor=user, task=task)
    return result


async def load_checkin_for(
    db: AsyncSession, user: User, checkin_id: uuid.UUID
) -> RhythmCheckin:
    """Own check-in in a project where the user is still a member (not viewer)."""
    checkin = await db.scalar(
        select(RhythmCheckin)
        .options(selectinload(RhythmCheckin.items))
        .where(RhythmCheckin.id == checkin_id)
    )
    if checkin is None or checkin.user_id != user.id:
        raise RhythmError("not_found", "Чек-ин не найден", 404)
    role = await db.scalar(
        select(ProjectMember.role).where(
            ProjectMember.project_id == checkin.project_id, ProjectMember.user_id == user.id
        )
    )
    if role not in (ProjectMemberRole.admin, ProjectMemberRole.member):
        raise RhythmError("forbidden", "Нет доступа к проекту", 403)
    return checkin


async def answer_checkin(
    db: AsyncSession,
    *,
    user: User,
    checkin: RhythmCheckin,
    answers: list[tuple[uuid.UUID, CheckinAnswer, str | None]],
) -> list[AppliedAnswer]:
    if checkin.status == CheckinStatus.skipped.value:
        raise RhythmError("expired", "Этот чек-ин уже неактуален", 409)
    by_task = {i.task_id: i for i in checkin.items}
    applied: list[AppliedAnswer] = []
    for task_id, answer, reason in answers:
        item = by_task.get(task_id)
        if item is None:
            raise RhythmError("not_in_checkin", "Задачи нет в этом чек-ине", 400)
        applied.append(
            await apply_answer(
                db, user=user, checkin=checkin, item=item, answer=answer, reason=reason
            )
        )
    if all(i.answer for i in checkin.items):
        checkin.status = CheckinStatus.answered.value
        checkin.answered_at = datetime.now(UTC)
    return applied


async def checkin_by_push_token(
    db: AsyncSession, checkin_id: uuid.UUID, token: str
) -> tuple[RhythmCheckin, User]:
    checkin = await db.scalar(
        select(RhythmCheckin)
        .options(selectinload(RhythmCheckin.items))
        .where(RhythmCheckin.id == checkin_id)
    )
    if (
        checkin is None
        or not checkin.push_token_hash
        or not secrets.compare_digest(checkin.push_token_hash, _hash_token(token))
    ):
        raise RhythmError("invalid_token", "Ссылка ответа недействительна", 403)
    project = await db.get(Project, checkin.project_id)
    if project is None or checkin.date != local_today(project):
        raise RhythmError("expired", "Этот чек-ин уже неактуален", 409)
    user = await db.get(User, checkin.user_id)
    if user is None or not user.is_active:
        raise RhythmError("invalid_token", "Ссылка ответа недействительна", 403)
    await load_checkin_for(db, user, checkin.id)
    return checkin, user
