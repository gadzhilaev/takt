# ruff: noqa: E501 — inline-styled HTML email template lines.
"""Digest («Сводка»): what was done, what is stuck, deadlines, bottleneck, rhythm participation.

Periods are rolling and counted in the project's timezone (``rhythm_timezone``):
``day`` = one local day, ``week`` = 7 local days, ``month`` = 30 local days, each ending on
``end_day`` (default — today). «Застряло», «Просрочено», «Скоро срок» are the current state.

Sources: done — ``tasks.closed_at`` in the period; stuck — ``tasks.blocked_at``;
bottleneck — column stays rebuilt from the move history (``activity_log``) and
``status_entered_at``; participation — ``rhythm_checkins`` (answered vs pending/skipped).

Logs contain only ids and counts.
"""

from __future__ import annotations

import asyncio
import html
import logging
import uuid
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import Settings, get_settings
from app.db.session import AsyncSessionLocal
from app.models.digest import DigestDelivery
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.push_subscription import PushSubscription
from app.models.rhythm import CheckinStatus, RhythmCheckin
from app.models.task import ActivityLog, Task, TaskAssignee
from app.models.team import TaskStatus
from app.models.user import User
from app.services import notify_service
from app.services.rhythm_service import project_zone

logger = logging.getLogger(__name__)

PERIOD_DAYS = {"day": 1, "week": 7, "month": 30}
PERIOD_TITLE = {"day": "за день", "week": "за неделю", "month": "за месяц"}
KIND_DIGEST = "digest"
DUE_SOON_HOURS = 48
FRIDAY = 5


class DigestError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


@dataclass(frozen=True)
class PeriodWindow:
    kind: str
    start_day: date
    end_day: date
    start_utc: datetime
    end_utc: datetime  # exclusive
    timezone: str


def period_window(
    project: Project, kind: str, *, end_day: date | None = None, now: datetime | None = None
) -> PeriodWindow:
    if kind not in PERIOD_DAYS:
        raise DigestError("invalid_period", "Период: day, week или month")
    tz = project_zone(project)
    now = now or datetime.now(UTC)
    end_day = end_day or now.astimezone(tz).date()
    start_day = end_day - timedelta(days=PERIOD_DAYS[kind] - 1)
    start_utc = datetime.combine(start_day, time(0), tz).astimezone(UTC)
    end_utc = datetime.combine(end_day + timedelta(days=1), time(0), tz).astimezone(UTC)
    return PeriodWindow(kind, start_day, end_day, start_utc, end_utc, str(tz))


def _aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)


def _task_row(task: Task, **extra) -> dict:
    return {
        "task_id": str(task.id),
        "title": task.title,
        "priority": task.priority.value,
        "status": task.status.name if task.status else None,
        "assignees": [a.user.name for a in task.assignees or [] if a.user],
        "due_date": task.due_date,
        **extra,
    }


def _bottleneck(
    tasks: list[Task],
    logs: list[ActivityLog],
    columns: dict[uuid.UUID, TaskStatus],
    window: PeriodWindow,
    now: datetime,
) -> dict | None:
    """Column with the largest average stay among stays that overlap the period.

    Stays are rebuilt from move history; the current stay ends «now». Done columns and
    columns that no longer exist are ignored.
    """
    by_task: dict[uuid.UUID, list[ActivityLog]] = defaultdict(list)
    for log in logs:
        by_task[log.task_id].append(log)
    horizon = min(now, window.end_utc)
    stays: dict[uuid.UUID, list[float]] = defaultdict(list)
    current: dict[uuid.UUID, list[tuple[Task, float]]] = defaultdict(list)

    def add(status_id: uuid.UUID | None, start: datetime, end: datetime | None, task: Task):
        col = columns.get(status_id) if status_id else None
        if col is None or col.is_done:
            return
        eff_end = end or now
        if eff_end <= window.start_utc or start >= horizon:
            return
        hours = max(0.0, (eff_end - start).total_seconds() / 3600)
        stays[col.id].append(hours)
        if end is None:
            current[col.id].append((task, hours))

    for task in tasks:
        moves = sorted(by_task.get(task.id, []), key=lambda lg: lg.created_at)
        start = _aware(task.created_at) or now
        cur: uuid.UUID | None
        if moves:
            try:
                cur = uuid.UUID(moves[0].old_value) if moves[0].old_value else task.status_id
            except ValueError:
                cur = task.status_id
        else:
            cur = task.status_id
        for log in moves:
            at = _aware(log.created_at) or now
            add(cur, start, at, task)
            try:
                cur = uuid.UUID(log.new_value) if log.new_value else cur
            except ValueError:
                pass
            start = at
        # Current stay: trust status_entered_at for the live column.
        if task.closed_at is None and task.status_id in columns:
            entered = _aware(task.status_entered_at) or start
            add(
                task.status_id,
                max(start, entered) if cur == task.status_id else entered,
                None,
                task,
            )

    if not stays:
        return None
    best_id = max(stays, key=lambda cid: sum(stays[cid]) / len(stays[cid]))
    values = stays[best_id]
    col = columns[best_id]
    now_there = sorted(current.get(best_id, []), key=lambda x: -x[1])[:5]
    return {
        "status_id": str(col.id),
        "name": col.name,
        "avg_hours": round(sum(values) / len(values), 1),
        "stays": len(values),
        "tasks": [_task_row(t, hours_in_status=round(h, 1)) for t, h in now_there],
    }


async def build_digest(
    db: AsyncSession,
    project: Project,
    *,
    kind: str = "week",
    end_day: date | None = None,
    now: datetime | None = None,
    include_members: bool = False,
) -> dict:
    now = now or datetime.now(UTC)
    window = period_window(project, kind, end_day=end_day, now=now)

    columns = {
        c.id: c
        for c in (
            await db.scalars(select(TaskStatus).where(TaskStatus.project_id == project.id))
        ).all()
    }
    tasks = list(
        (
            await db.execute(
                select(Task)
                .options(
                    selectinload(Task.status),
                    selectinload(Task.assignees).selectinload(TaskAssignee.user),
                    selectinload(Task.blocked_by),
                )
                .where(Task.project_id == project.id, Task.deleted_at.is_(None))
            )
        )
        .scalars()
        .unique()
        .all()
    )

    def is_open(t: Task) -> bool:
        return t.closed_at is None and not (t.status and t.status.is_done) and t.archived_at is None

    done = sorted(
        (
            t
            for t in tasks
            if t.closed_at is not None and window.start_utc <= _aware(t.closed_at) < window.end_utc
        ),
        key=lambda t: _aware(t.closed_at),
        reverse=True,
    )
    stuck = sorted(
        (t for t in tasks if is_open(t) and t.blocked_at is not None),
        key=lambda t: _aware(t.blocked_at),
    )
    overdue = sorted(
        (t for t in tasks if is_open(t) and t.due_date and _aware(t.due_date) < now),
        key=lambda t: _aware(t.due_date),
    )
    soon_until = now + timedelta(hours=DUE_SOON_HOURS)
    due_soon = sorted(
        (t for t in tasks if is_open(t) and t.due_date and now <= _aware(t.due_date) < soon_until),
        key=lambda t: _aware(t.due_date),
    )

    task_ids = [t.id for t in tasks]
    logs = (
        list(
            (
                await db.scalars(
                    select(ActivityLog).where(
                        ActivityLog.task_id.in_(task_ids), ActivityLog.field == "status_id"
                    )
                )
            ).all()
        )
        if task_ids
        else []
    )
    bottleneck = _bottleneck(tasks, logs, columns, window, now)

    checkins = (
        await db.execute(
            select(RhythmCheckin, User)
            .join(User, User.id == RhythmCheckin.user_id)
            .where(
                RhythmCheckin.project_id == project.id,
                RhythmCheckin.date >= window.start_day,
                RhythmCheckin.date <= window.end_day,
            )
        )
    ).all()
    # Today's still-open check-in is not a miss yet — leave it out until the day is over.
    today_local = now.astimezone(project_zone(project)).date()
    checkins = [
        (c, u)
        for c, u in checkins
        if not (c.status == CheckinStatus.pending.value and c.date >= today_local)
    ]
    total = len(checkins)
    answered = sum(1 for c, _u in checkins if c.status == CheckinStatus.answered.value)
    rhythm: dict = {
        "enabled": bool(project.rhythm_enabled),
        "total": total,
        "answered": answered,
        "participation": round(answered * 100 / total) if total else None,
    }
    if include_members:
        per: dict[uuid.UUID, dict] = {}
        for c, u in checkins:
            row = per.setdefault(
                u.id, {"user_id": str(u.id), "name": u.name, "total": 0, "missed": 0}
            )
            row["total"] += 1
            if c.status != CheckinStatus.answered.value:
                row["missed"] += 1
        # Neutral wording on clients: «без ответа: N из M». Only people with misses.
        rhythm["members_without_answer"] = sorted(
            (r for r in per.values() if r["missed"]), key=lambda r: (-r["missed"], r["name"])
        )

    def stuck_row(t: Task) -> dict:
        since = _aware(t.blocked_at)
        return _task_row(
            t,
            reason=t.blocked_reason,
            blocked_by=t.blocked_by.name if t.blocked_by else None,
            days_stuck=max(0, (now - since).days) if since else 0,
            blocked_at=since,
        )

    return {
        "project": {"id": str(project.id), "name": project.name},
        "period": {
            "kind": kind,
            "start": window.start_day.isoformat(),
            "end": window.end_day.isoformat(),
            "timezone": window.timezone,
        },
        "summary": {
            "done": len(done),
            "stuck": len(stuck),
            "overdue": len(overdue),
            "due_soon": len(due_soon),
            "participation": rhythm["participation"],
        },
        "done": [_task_row(t, closed_at=_aware(t.closed_at)) for t in done[:50]],
        "stuck": [stuck_row(t) for t in stuck],
        "overdue": [_task_row(t) for t in overdue],
        "due_soon": [_task_row(t) for t in due_soon],
        "bottleneck": bottleneck,
        "rhythm": rhythm,
        "includes_members": include_members,
    }


# ---------------------------------------------------------------- texts


def _plural(n: int, one: str, few: str, many: str) -> str:
    n100, n10 = n % 100, n % 10
    if 11 <= n100 <= 14:
        return many
    if n10 == 1:
        return one
    if 2 <= n10 <= 4:
        return few
    return many


def short_text(digest: dict) -> str:
    """«Сводка за неделю: 12 сделано, 2 застряли»."""
    s = digest["summary"]
    kind = digest["period"]["kind"]
    stuck = s["stuck"]
    stuck_word = _plural(stuck, "застряла", "застряли", "застряли")
    return f"Сводка {PERIOD_TITLE[kind]}: {s['done']} сделано, {stuck} {stuck_word}"


def email_bodies(digest: dict, *, app_url: str) -> tuple[str, str, str]:
    """(subject, text, html) — simple inline-styled letter, no tracking."""
    p = digest["project"]
    s = digest["summary"]
    subject = f"{short_text(digest)} · {p['name']}"
    link = f"{app_url.rstrip('/')}/app/projects/{p['id']}?view=digest&period={digest['period']['kind']}"
    lines = [short_text(digest), f"Проект: {p['name']}", ""]
    if digest["stuck"]:
        lines.append("Застряло:")
        lines += [f"— {t['title']}: {t.get('reason') or 'без причины'}" for t in digest["stuck"]]
    if digest["overdue"]:
        lines.append("Просрочено:")
        lines += [f"— {t['title']}" for t in digest["overdue"]]
    if digest["bottleneck"]:
        b = digest["bottleneck"]
        lines.append(f"Узкое место: «{b['name']}», в среднем {b['avg_hours']} ч")
    lines += ["", f"Открыть сводку: {link}"]
    text = "\n".join(lines)

    def items(title: str, rows: list[dict], extra) -> str:
        if not rows:
            return ""
        lis = "".join(
            f'<li style="margin:4px 0">{html.escape(r["title"])}{extra(r)}</li>' for r in rows
        )
        return f'<h3 style="font-size:15px;margin:18px 0 6px">{title}</h3><ul style="padding-left:18px;margin:0">{lis}</ul>'

    def reason(r: dict) -> str:
        return (
            f' <span style="color:#9a6700">— {html.escape(r["reason"])}</span>'
            if r.get("reason")
            else ""
        )

    numbers = "".join(
        f'<td style="padding:8px 12px;text-align:center"><div style="font-size:22px;font-weight:600">{v}</div>'
        f'<div style="font-size:12px;color:#667485">{label}</div></td>'
        for v, label in (
            (s["done"], "сделано"),
            (s["stuck"], "застряло"),
            (s["overdue"], "просрочено"),
            (
                f"{s['participation']}%" if s["participation"] is not None else "—",
                "ответы на чек-ин",
            ),
        )
    )
    bottleneck = ""
    if digest["bottleneck"]:
        b = digest["bottleneck"]
        bottleneck = (
            f'<h3 style="font-size:15px;margin:18px 0 6px">Узкое место</h3>'
            f'<p style="margin:0">«{html.escape(b["name"])}» — в среднем {b["avg_hours"]} ч в столбце</p>'
        )
    body = (
        '<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#202938;max-width:560px">'
        f'<h2 style="font-size:18px;margin:0 0 4px">{html.escape(short_text(digest))}</h2>'
        f'<p style="margin:0 0 12px;color:#667485">{html.escape(p["name"])}</p>'
        f'<table style="border-collapse:collapse;background:#f1f3f5;border-radius:8px"><tr>{numbers}</tr></table>'
        + items("Застряло", digest["stuck"], reason)
        + items("Просрочено", digest["overdue"], lambda r: "")
        + bottleneck
        + f'<p style="margin:20px 0 0"><a href="{html.escape(link)}" style="color:#315F72">Открыть сводку в Takt</a></p>'
        "</div>"
    )
    return subject, text, body


# ---------------------------------------------------------------- delivery


def due_periods(
    project: Project, now: datetime, *, window_hours: int = 3
) -> list[tuple[str, date]]:
    """Which digests are due now: daily at ``digest_time``, weekly on Friday at ``digest_time``."""
    if project.is_archived or not (project.digest_daily or project.digest_weekly):
        return []
    local = now.astimezone(project_zone(project))
    start = datetime.combine(local.date(), project.digest_time or time(18, 0), local.tzinfo)
    if not (start <= local < start + timedelta(hours=max(1, window_hours))):
        return []
    out: list[tuple[str, date]] = []
    if project.digest_daily:
        out.append(("day", local.date()))
    if project.digest_weekly and local.isoweekday() == FRIDAY:
        out.append(("week", local.date()))
    return out


async def recipients(db: AsyncSession, project: Project) -> list[tuple[User, bool]]:
    """(user, is_admin): every subscribed member (subscription is on by default)."""
    rows = (
        await db.execute(
            select(User, ProjectMember.role, ProjectMember.digest_subscribed)
            .join(ProjectMember, ProjectMember.user_id == User.id)
            .where(
                ProjectMember.project_id == project.id,
                User.is_active.is_(True),
                User.is_demo.is_(False),
            )
        )
    ).all()
    return [(u, role == ProjectMemberRole.admin) for u, role, subscribed in rows if subscribed]


async def deliver_digest(
    db: AsyncSession,
    project: Project,
    *,
    kind: str,
    end_day: date,
    settings: Settings,
    now: datetime | None = None,
    push: bool = True,
    only_user_ids: set[uuid.UUID] | None = None,
) -> int:
    """Send one period's digest to every recipient once (unique project+period+recipient).

    Returns the number of new deliveries. Caller commits.
    """
    now = now or datetime.now(UTC)
    targets = await recipients(db, project)
    if only_user_ids is not None:
        targets = [(u, a) for u, a in targets if u.id in only_user_ids]
    if not targets:
        return 0
    full = await build_digest(
        db, project, kind=kind, end_day=end_day, now=now, include_members=True
    )
    brief = {
        **full,
        "rhythm": {k: v for k, v in full["rhythm"].items() if k != "members_without_answer"},
        "includes_members": False,
    }
    sent = 0
    for user, is_admin in targets:
        delivery = await db.scalar(
            select(DigestDelivery).where(
                DigestDelivery.project_id == project.id,
                DigestDelivery.recipient_id == user.id,
                DigestDelivery.period == kind,
                DigestDelivery.period_end == end_day,
            )
        )
        created = delivery is None
        if created:
            try:
                async with db.begin_nested():
                    delivery = DigestDelivery(
                        project_id=project.id,
                        recipient_id=user.id,
                        period=kind,
                        period_end=end_day,
                        created_at=now,
                        channels="in_app",
                    )
                    db.add(delivery)
                    await db.flush()
            except IntegrityError:
                # Another worker may have created the idempotency row between the read and insert.
                delivery = await db.scalar(
                    select(DigestDelivery).where(
                        DigestDelivery.project_id == project.id,
                        DigestDelivery.recipient_id == user.id,
                        DigestDelivery.period == kind,
                        DigestDelivery.period_end == end_day,
                    )
                )
                created = False
            else:
                await notify_service.create_in_app(
                    db,
                    user_id=user.id,
                    actor_id=None,
                    kind=KIND_DIGEST,
                    title=short_text(full if is_admin else brief),
                    body=f"Проект {project.name}",
                    project_id=project.id,
                )
        if delivery is None:
            continue

        channels = set((delivery.channels or "").split(","))
        # Older releases stored a single `push` flag after calling both providers. Keep FCM
        # from being duplicated, but retry Web Push if this account subscribed after that send.
        if "push" in channels:
            channels.discard("push")
            channels.add("fcm")
            web_subscription_at_delivery = await db.scalar(
                select(PushSubscription.id)
                .where(
                    PushSubscription.user_id == user.id,
                    PushSubscription.updated_at <= delivery.created_at,
                )
                .limit(1)
            )
            if web_subscription_at_delivery is not None:
                channels.add("web_push")
        digest = full if is_admin else brief
        title = short_text(digest)
        url = f"/app/projects/{project.id}?view=digest&period={kind}"
        if push and "push" not in channels:
            from app.services import fcm_service, push_service

            if "web_push" not in channels:
                web_accepted = await push_service.send_push_to_users(
                    db,
                    settings,
                    user_ids=[user.id],
                    title=title,
                    body=project.name,
                    url=url,
                    tag=f"digest-{project.id}-{kind}",
                )
                if web_accepted:
                    channels.add("web_push")
            if "fcm" not in channels:
                fcm_accepted = await fcm_service.send_fcm_to_users(
                    db,
                    settings,
                    user_ids=[user.id],
                    title=title,
                    body=project.name,
                    data={
                        "kind": KIND_DIGEST,
                        "project_id": str(project.id),
                        "period": kind,
                        "url": url,
                    },
                )
                if fcm_accepted:
                    channels.add("fcm")
            delivery.channels = (
                ",".join(
                    channel for channel in ("in_app", "web_push", "fcm") if channel in channels
                )
                or "in_app"
            )
        if push and settings.DIGEST_EMAIL_ENABLED and "email" not in channels:
            from app.services import email_service

            subject, text_body, html_body = email_bodies(digest, app_url=settings.APP_PUBLIC_URL)
            try:
                await email_service.send_html_email(
                    to=user.email, subject=subject, text_body=text_body, html_body=html_body
                )
                channels.add("email")
            except Exception:  # noqa: BLE001 — a failed letter must not block in-app/push
                logger.exception("digest email failed for project %s", project.id)
        delivery.channels = (
            ",".join(
                channel for channel in ("in_app", "web_push", "fcm", "email") if channel in channels
            )
            or "in_app"
        )
        sent += int(created)
    return sent


async def run_digest_pass(
    settings: Settings | None = None, now: datetime | None = None
) -> dict[str, int]:
    """One iteration of the digest loop. Each project gets its own DB session."""
    settings = settings or get_settings()
    now = now or datetime.now(UTC)
    totals = {"projects": 0, "sent": 0, "failed_projects": 0}
    async with AsyncSessionLocal() as db:
        project_ids = (
            await db.scalars(
                select(Project.id).where(
                    Project.is_archived.is_(False),
                    (Project.digest_daily.is_(True)) | (Project.digest_weekly.is_(True)),
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
                due = due_periods(project, now, window_hours=settings.DIGEST_WINDOW_HOURS)
                sent = 0
                for kind, end_day in due:
                    sent += await deliver_digest(
                        db, project, kind=kind, end_day=end_day, settings=settings, now=now
                    )
                if due:
                    # A retry may update provider channel state without creating a new in-app
                    # delivery row; commit those channel updates even when `sent == 0`.
                    await db.commit()
                else:
                    await db.rollback()
                totals["sent"] += sent
        except Exception:
            totals["failed_projects"] += 1
            logger.exception("digest pass failed for project %s", project_id)
    logger.info(
        "digest pass ok: projects=%s sent=%s failed=%s",
        totals["projects"],
        totals["sent"],
        totals["failed_projects"],
    )
    return totals


async def digest_loop(stop: asyncio.Event) -> None:
    settings = get_settings()
    if not settings.DIGEST_ENABLED or settings.DIGEST_INTERVAL_SECONDS <= 0:
        return
    interval = max(30, int(settings.DIGEST_INTERVAL_SECONDS))
    while not stop.is_set():
        await run_digest_pass(settings)
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except TimeoutError:
            continue
