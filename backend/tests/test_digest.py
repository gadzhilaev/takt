"""Digest («Сводка»): metrics, periods in project timezone, rights, idempotent delivery, loop."""

from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import UTC, date, datetime, time, timedelta
from types import SimpleNamespace

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import engine
from app.main import app
from app.models.digest import DigestDelivery
from app.models.notification import Notification
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.rhythm import RhythmCheckin
from app.models.task import ActivityLog, Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User
from app.services import digest_service
from app.services.digest_service import (
    build_digest,
    deliver_digest,
    digest_loop,
    due_periods,
    period_window,
    run_digest_pass,
    short_text,
)
from app.services.project_service import DEFAULT_STATUS_TEMPLATE
from tests.conftest import TestSession

PASSWORD = "Digest-Pass-123!"
MSK = "Europe/Moscow"
# 2026-11-20 is a Friday; 15:30 UTC = 18:30 Moscow.
FRIDAY_1830_MSK = datetime(2026, 11, 20, 15, 30, tzinfo=UTC)


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_pool():
    await engine.dispose()
    yield
    await engine.dispose()


def _p(**kw):
    base = dict(
        rhythm_timezone=MSK,
        is_archived=False,
        digest_daily=False,
        digest_weekly=True,
        digest_time=time(18, 0),
    )
    base.update(kw)
    return SimpleNamespace(**base)


def test_period_window_uses_project_timezone():
    now = datetime(2026, 11, 15, 22, 30, tzinfo=UTC)  # already Monday 16th in Vladivostok
    w = period_window(_p(rhythm_timezone="Asia/Vladivostok"), "day", now=now)
    assert w.end_day == date(2026, 11, 16)
    assert w.start_utc == datetime(2026, 11, 15, 14, 0, tzinfo=UTC)  # 00:00 +10
    assert w.end_utc == datetime(2026, 11, 16, 14, 0, tzinfo=UTC)
    week = period_window(_p(), "week", end_day=date(2026, 11, 20))
    assert (week.start_day, week.end_day) == (date(2026, 11, 14), date(2026, 11, 20))
    assert week.start_utc == datetime(2026, 11, 13, 21, 0, tzinfo=UTC)  # 00:00 MSK
    assert period_window(_p(), "month", end_day=date(2026, 11, 30)).start_day == date(2026, 11, 1)
    with pytest.raises(digest_service.DigestError):
        period_window(_p(), "year")


def test_due_periods_daily_and_friday_weekly():
    assert due_periods(_p(), FRIDAY_1830_MSK) == [("week", date(2026, 11, 20))]
    both = due_periods(_p(digest_daily=True), FRIDAY_1830_MSK)
    assert both == [("day", date(2026, 11, 20)), ("week", date(2026, 11, 20))]
    thursday = FRIDAY_1830_MSK - timedelta(days=1)
    assert due_periods(_p(), thursday) == []
    assert due_periods(_p(digest_daily=True), thursday) == [("day", date(2026, 11, 19))]
    assert due_periods(_p(), FRIDAY_1830_MSK - timedelta(hours=1)) == []  # before 18:00
    assert due_periods(_p(), FRIDAY_1830_MSK + timedelta(hours=3)) == []  # after window
    assert due_periods(_p(digest_weekly=False), FRIDAY_1830_MSK) == []
    assert due_periods(_p(is_archived=True), FRIDAY_1830_MSK) == []


def test_short_text():
    d = {"summary": {"done": 12, "stuck": 2}, "period": {"kind": "week"}}
    assert short_text(d) == "Сводка за неделю: 12 сделано, 2 застряли"
    d = {"summary": {"done": 1, "stuck": 1}, "period": {"kind": "day"}}
    assert short_text(d) == "Сводка за день: 1 сделано, 1 застряла"


async def _user(db, email, name, *, demo=False) -> User:
    u = User(email=email, name=name, password_hash=hash_password(PASSWORD), is_demo=demo)
    db.add(u)
    await db.flush()
    return u


async def _world(now: datetime) -> SimpleNamespace:
    async with TestSession() as db:
        tag = uuid.uuid4().hex[:6]
        admin = await _user(db, f"d-admin-{tag}@example.com", "Админ Сводки")
        member = await _user(db, f"d-member-{tag}@example.com", "Участник Сводки")
        sub = await _user(db, f"d-sub-{tag}@example.com", "Подписчик Сводки")
        demo = await _user(db, f"d-demo-{tag}@example.com", "Демо Сводки", demo=True)
        viewer = await _user(db, f"d-viewer-{tag}@example.com", "Наблюдатель Сводки")
        project = Project(name="Сводка", rhythm_enabled=True, rhythm_timezone=MSK)
        db.add(project)
        await db.flush()
        cols = []
        for pos, (n, c, _p2, d) in enumerate(DEFAULT_STATUS_TEMPLATE):
            s = TaskStatus(project_id=project.id, name=n, color=c, position=float(pos), is_done=d)
            db.add(s)
            cols.append(s)
        await db.flush()
        for u, r, subscribed in (
            (admin, ProjectMemberRole.admin, True),
            (viewer, ProjectMemberRole.viewer, True),
            (member, ProjectMemberRole.member, False),
            (sub, ProjectMemberRole.member, True),
            (demo, ProjectMemberRole.member, True),
        ):
            db.add(
                ProjectMember(
                    project_id=project.id, user_id=u.id, role=r, digest_subscribed=subscribed
                )
            )

        async def task(title, col, *, created, closed=None, due=None, blocked=None, entered=None):
            t = Task(
                project_id=project.id,
                title=title,
                status_id=cols[col].id,
                priority=TaskPriority.medium,
                author_id=admin.id,
                position=0.0,
                created_at=created,
                closed_at=closed,
                due_date=due,
                status_entered_at=entered or created,
            )
            if blocked:
                t.blocked_at, t.blocked_reason, t.blocked_by_id = blocked
            db.add(t)
            await db.flush()
            db.add(TaskAssignee(task_id=t.id, user_id=member.id))
            return t

        d = timedelta(days=1)
        done_in = await task("Сделано в периоде", 3, created=now - 6 * d, closed=now - 2 * d)
        done_old = await task("Сделано давно", 3, created=now - 30 * d, closed=now - 20 * d)
        stuck = await task(
            "Застряла",
            1,
            created=now - 5 * d,
            blocked=(now - 3 * d, "Ждём подпись", member.id),
        )
        overdue = await task("Просрочена", 0, created=now - 4 * d, due=now - d)
        soon = await task("Скоро срок", 0, created=now - d, due=now + timedelta(hours=10))
        later = await task("Срок нескоро", 0, created=now - d, due=now + 10 * d)
        nodue = await task("Без срока", 0, created=now - d)
        # Move history: «В работе» held 3 days, «На проверке» 1 day.
        mover = await task("Двигалась", 3, created=now - 6 * d, closed=now - d)

        def mv(t, frm, to, at):
            db.add(
                ActivityLog(
                    task_id=t.id,
                    user_id=member.id,
                    action="moved",
                    field="status_id",
                    old_value=str(frm),
                    new_value=str(to),
                    created_at=at,
                )
            )

        mv(mover, cols[0].id, cols[1].id, now - 5 * d)
        mv(mover, cols[1].id, cols[2].id, now - 2 * d)
        mv(mover, cols[2].id, cols[3].id, now - d)
        # A move from a column that no longer exists must be ignored.
        mv(done_in, uuid.uuid4(), cols[3].id, now - 2 * d)

        today = now.astimezone(digest_service.project_zone(project)).date()
        for i, (u, status) in enumerate(
            [(member, "answered"), (member, "skipped"), (member, "answered"), (admin, "answered")]
        ):
            db.add(
                RhythmCheckin(
                    user_id=u.id,
                    project_id=project.id,
                    date=today - timedelta(days=i + 1),
                    status=status,
                )
            )
        # Today's pending check-in is still open — must not count as «без ответа».
        db.add(
            RhythmCheckin(user_id=member.id, project_id=project.id, date=today, status="pending")
        )
        await db.commit()
        return SimpleNamespace(
            project_id=project.id,
            admin=admin,
            member=member,
            sub=sub,
            viewer=viewer,
            demo=demo,
            ids={
                k: str(v.id)
                for k, v in dict(
                    done_in=done_in,
                    done_old=done_old,
                    stuck=stuck,
                    overdue=overdue,
                    soon=soon,
                    later=later,
                    nodue=nodue,
                    mover=mover,
                ).items()
            },
            cols=cols,
        )


@pytest.mark.asyncio
async def test_metrics_week():
    now = datetime.now(UTC)
    w = await _world(now)
    async with TestSession() as db:
        project = await db.get(Project, w.project_id)
        d = await build_digest(db, project, kind="week", now=now, include_members=True)
    ids = w.ids
    assert {t["task_id"] for t in d["done"]} == {ids["done_in"], ids["mover"]}
    assert d["summary"]["done"] == 2
    [stuck] = d["stuck"]
    assert stuck["task_id"] == ids["stuck"] and stuck["reason"] == "Ждём подпись"
    assert stuck["days_stuck"] == 3 and stuck["blocked_by"] == "Участник Сводки"
    assert [t["task_id"] for t in d["overdue"]] == [ids["overdue"]]
    assert [t["task_id"] for t in d["due_soon"]] == [ids["soon"]]  # no-due / far tasks excluded
    b = d["bottleneck"]
    assert b["name"] == "В работе"  # stuck task ~5 days + mover 3 days
    assert b["avg_hours"] > 72
    assert d["rhythm"]["total"] == 4 and d["rhythm"]["answered"] == 3
    assert d["rhythm"]["participation"] == 75
    assert d["rhythm"]["members_without_answer"] == [
        {"user_id": str(w.member.id), "name": "Участник Сводки", "total": 3, "missed": 1}
    ]
    assert d["period"]["timezone"] == MSK

    async with TestSession() as db:
        project = await db.get(Project, w.project_id)
        day = await build_digest(db, project, kind="day", now=now)
    assert day["summary"]["done"] == 0  # nothing closed today
    assert "members_without_answer" not in day["rhythm"]


@pytest.mark.asyncio
async def test_empty_project():
    async with TestSession() as db:
        p = Project(name="Пустой", rhythm_timezone=MSK)
        db.add(p)
        await db.commit()
        d = await build_digest(db, p, kind="month")
    assert d["summary"] == {
        "done": 0,
        "stuck": 0,
        "overdue": 0,
        "due_soon": 0,
        "participation": None,
    }
    assert d["bottleneck"] is None and d["done"] == []


async def _client():
    from app.db.session import get_db

    async def override_get_db():
        async with TestSession() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _login(c: AsyncClient, user: User) -> dict:
    r = await c.post("/api/v1/auth/login", json={"email": user.email, "password": PASSWORD})
    assert r.status_code == 200, r.text
    return {"X-CSRF-Token": c.cookies.get("csrf_token") or ""}


@pytest.mark.asyncio
async def test_api_rights_and_subscription(client):
    w = await _world(datetime.now(UTC))
    url = f"/api/v1/projects/{w.project_id}/digest"

    await _login(client, w.admin)
    r = await client.get(url, params={"period": "week"})
    assert r.status_code == 200, r.text
    d = r.json()["digest"]
    assert d["viewer"] == {"is_admin": True, "subscribed": True}
    assert "members_without_answer" in d["rhythm"]
    assert d["schedule"] == {"daily": False, "weekly": True, "time": "18:00"}
    assert (await client.get(url, params={"period": "year"})).status_code == 422

    async with await _client() as c:
        h = await _login(c, w.member)
        d = (await c.get(url)).json()["digest"]
        assert d["viewer"] == {"is_admin": False, "subscribed": False}
        assert "members_without_answer" not in d["rhythm"]  # per-member details: admins only
        assert d["summary"]["done"] == 2
        r = await c.put(f"{url}-subscription", headers=h, json={"subscribed": True})
        assert r.json() == {"subscribed": True}
        assert (await c.get(url)).json()["digest"]["viewer"]["subscribed"] is True

    # Viewer sees the summary too, but not who missed check-ins.
    async with await _client() as c:
        await _login(c, w.viewer)
        d = (await c.get(url)).json()["digest"]
        assert d["summary"]["done"] == 2 and d["rhythm"]["participation"] == 75
        assert "members_without_answer" not in d["rhythm"]

    # Admin can opt out as well.
    h = await _login(client, w.admin)
    r = await client.put(f"{url}-subscription", headers=h, json={"subscribed": False})
    assert r.json() == {"subscribed": False}
    assert (await client.get(url)).json()["digest"]["viewer"]["subscribed"] is False

    async with TestSession() as db:
        outsider = await _user(db, "d-outsider@example.com", "Чужой")
        await db.commit()
    async with await _client() as c:
        h = await _login(c, outsider)
        assert (await c.get(url)).status_code == 403
        assert (
            await c.put(f"{url}-subscription", headers=h, json={"subscribed": True})
        ).status_code == 403

    # Schedule is part of project settings (admin only)
    h = await _login(client, w.admin)
    r = await client.patch(
        f"/api/v1/projects/{w.project_id}",
        headers=h,
        json={"digest_daily": True, "digest_weekly": False, "digest_time": "17:30"},
    )
    assert r.json()["project"]["digest"] == {"daily": True, "weekly": False, "time": "17:30"}


@pytest.mark.asyncio
async def test_delivery_idempotent_admins_and_subscribers(monkeypatch):
    pushes, emails = [], []

    async def fake_fcm(db, s, *, user_ids, title, body, data=None, **kw):
        pushes.append((user_ids[0], title))

    async def fake_webpush(*a, **kw):
        pass

    async def fake_email(*, to, subject, text_body, html_body):
        emails.append((to, subject, html_body))

    from app.services import email_service, fcm_service, push_service

    monkeypatch.setattr(fcm_service, "send_fcm_to_users", fake_fcm)
    monkeypatch.setattr(push_service, "send_push_to_users", fake_webpush)
    monkeypatch.setattr(email_service, "send_html_email", fake_email)
    settings = get_settings()
    monkeypatch.setattr(settings, "DIGEST_EMAIL_ENABLED", False)

    now = datetime.now(UTC)
    w = await _world(now)
    async with TestSession() as db:
        project = await db.get(Project, w.project_id)
        end_day = period_window(project, "week", now=now).end_day
        sent = await deliver_digest(
            db, project, kind="week", end_day=end_day, settings=settings, now=now
        )
        await db.commit()
    # Everyone subscribed (admin, member, viewer); demo and the opted-out member — no.
    assert sent == 3
    assert {u for u, _t in pushes} == {w.admin.id, w.sub.id, w.viewer.id}
    assert pushes[0][1] == "Сводка за неделю: 2 сделано, 1 застряла"
    assert emails == []  # DIGEST_EMAIL_ENABLED=false by default

    async with TestSession() as db:
        project = await db.get(Project, w.project_id)
        again = await deliver_digest(
            db, project, kind="week", end_day=end_day, settings=settings, now=now
        )
        await db.commit()
        assert again == 0
        n = await db.scalar(
            select(func.count())
            .select_from(DigestDelivery)
            .where(DigestDelivery.project_id == w.project_id)
        )
        assert n == 3
        notes = (
            await db.scalars(
                select(Notification.title).where(
                    Notification.kind == "digest", Notification.user_id == w.admin.id
                )
            )
        ).all()
        assert notes == ["Сводка за неделю: 2 сделано, 1 застряла"]

    monkeypatch.setattr(settings, "DIGEST_EMAIL_ENABLED", True)
    async with TestSession() as db:
        project = await db.get(Project, w.project_id)
        await deliver_digest(db, project, kind="day", end_day=end_day, settings=settings, now=now)
        await db.commit()
    assert {to for to, _s, _h in emails} == {w.admin.email, w.sub.email, w.viewer.email}
    admin_html = next(h for to, _s, h in emails if to == w.admin.email)
    assert "Ждём подпись" in admin_html and "Узкое место" in admin_html
    assert f"/app/projects/{w.project_id}?view=digest&amp;period=day" in admin_html


@pytest.mark.asyncio
async def test_loop_iteration_sends_digest(monkeypatch, caplog):
    """Through digest_loop itself: an iteration at Friday 18:30 sends the weekly digest."""

    async def nothing(*a, **kw):
        pass

    from app.services import fcm_service, push_service

    monkeypatch.setattr(fcm_service, "send_fcm_to_users", nothing)
    monkeypatch.setattr(push_service, "send_push_to_users", nothing)
    settings = get_settings()
    monkeypatch.setattr(settings, "DIGEST_ENABLED", True)
    monkeypatch.setattr(settings, "DIGEST_INTERVAL_SECONDS", 60)
    w = await _world(FRIDAY_1830_MSK)

    real_pass = digest_service.run_digest_pass

    async def pass_at_friday(s=None, now=None):
        return await real_pass(s, now=FRIDAY_1830_MSK)

    monkeypatch.setattr(digest_service, "run_digest_pass", pass_at_friday)

    async def delivered() -> int:
        async with TestSession() as db:
            return await db.scalar(
                select(func.count())
                .select_from(DigestDelivery)
                .where(DigestDelivery.project_id == w.project_id)
            )

    stop = asyncio.Event()
    with caplog.at_level(logging.INFO, logger="app.services.digest_service"):
        task = asyncio.create_task(digest_loop(stop))
        for _ in range(100):
            if await delivered():
                break
            await asyncio.sleep(0.05)
        stop.set()
        await asyncio.wait_for(task, timeout=5)
    assert await delivered() == 3
    assert "digest pass ok" in caplog.text
    assert "Админ" not in caplog.text and "@example.com" not in caplog.text

    # Outside the window nothing is sent.
    res = await run_digest_pass(settings, now=FRIDAY_1830_MSK - timedelta(hours=2))
    assert res["sent"] == 0
