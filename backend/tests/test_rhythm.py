"""Rhythm: generation of daily check-ins, answers, access rules, «blocked» flag, loop."""

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
from app.models.notification import Notification
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.rhythm import RhythmCheckin, RhythmCheckinItem
from app.models.task import ActivityLog, Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User
from app.services.project_service import DEFAULT_STATUS_TEMPLATE
from app.services.rhythm_service import checkin_day, rhythm_loop, run_rhythm_pass
from tests.conftest import TestSession

PASSWORD = "Rhythm-Pass-123!"
MSK = "Europe/Moscow"


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_pool():
    # run_rhythm_pass uses the app engine; don't carry pooled connections across event loops.
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.fixture
def settings(monkeypatch):
    s = get_settings()
    monkeypatch.setattr(s, "RHYTHM_WINDOW_HOURS", 3)
    monkeypatch.setattr(s, "RHYTHM_MAX_TASKS", 5)
    return s


def _project_ns(**kw):
    base = dict(
        rhythm_enabled=True,
        is_archived=False,
        rhythm_timezone=MSK,
        rhythm_time=time(10, 0),
        rhythm_days=[1, 2, 3, 4, 5],
    )
    base.update(kw)
    return SimpleNamespace(**base)


# 2026-11-16 is a Monday. 07:30 UTC = 10:30 in Moscow.
MONDAY_1030_MSK = datetime(2026, 11, 16, 7, 30, tzinfo=UTC)


def test_checkin_day_time_days_and_timezone():
    p = _project_ns()
    assert checkin_day(p, MONDAY_1030_MSK) == date(2026, 11, 16)
    # before check-in time
    assert checkin_day(p, MONDAY_1030_MSK - timedelta(hours=1)) is None
    # after the 3h window
    assert checkin_day(p, MONDAY_1030_MSK + timedelta(hours=3)) is None
    # Saturday is not a working day by default
    assert checkin_day(p, MONDAY_1030_MSK + timedelta(days=5)) is None
    assert checkin_day(_project_ns(rhythm_days=[6]), MONDAY_1030_MSK + timedelta(days=5)) == date(
        2026, 11, 21
    )
    # same instant is 17:30 in Vladivostok → outside 10:00–13:00
    assert checkin_day(_project_ns(rhythm_timezone="Asia/Vladivostok"), MONDAY_1030_MSK) is None
    # local date differs from UTC date: 23:30 UTC Sunday = 09:30 Monday in Vladivostok (UTC+10)
    vl = _project_ns(rhythm_timezone="Asia/Vladivostok", rhythm_time=time(9, 0))
    assert checkin_day(vl, datetime(2026, 11, 15, 23, 30, tzinfo=UTC)) == date(2026, 11, 16)
    # disabled / archived
    assert checkin_day(_project_ns(rhythm_enabled=False), MONDAY_1030_MSK) is None
    assert checkin_day(_project_ns(is_archived=True), MONDAY_1030_MSK) is None


async def _user(db, email: str, name: str, *, demo: bool = False) -> User:
    u = User(email=email, name=name, password_hash=hash_password(PASSWORD), is_demo=demo)
    db.add(u)
    await db.flush()
    return u


async def _world(*, rhythm_time: time = time(10, 0), days=None) -> SimpleNamespace:
    """Project with 4 columns; admin + member with tasks, viewer, demo, member without tasks."""
    async with TestSession() as db:
        admin = await _user(db, f"admin-{uuid.uuid4().hex[:6]}@example.com", "Админ Проекта")
        member = await _user(db, f"member-{uuid.uuid4().hex[:6]}@example.com", "Участник Один")
        idle = await _user(db, f"idle-{uuid.uuid4().hex[:6]}@example.com", "Без Задач")
        viewer = await _user(db, f"viewer-{uuid.uuid4().hex[:6]}@example.com", "Наблюдатель")
        demo = await _user(db, f"demo-{uuid.uuid4().hex[:6]}@example.com", "Демо", demo=True)
        project = Project(
            name="Ритм",
            rhythm_enabled=True,
            rhythm_time=rhythm_time,
            rhythm_timezone=MSK,
            rhythm_days=days or [1, 2, 3, 4, 5],
        )
        db.add(project)
        await db.flush()
        cols = []
        for pos, (name, color, _p, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
            c = TaskStatus(
                project_id=project.id, name=name, color=color, position=float(pos), is_done=is_done
            )
            db.add(c)
            cols.append(c)
        await db.flush()
        for u, role in (
            (admin, ProjectMemberRole.admin),
            (member, ProjectMemberRole.member),
            (idle, ProjectMemberRole.member),
            (viewer, ProjectMemberRole.viewer),
            (demo, ProjectMemberRole.member),
        ):
            db.add(ProjectMember(project_id=project.id, user_id=u.id, role=role))

        now = datetime.now(UTC)

        async def task(title, who, *, col=0, due=None, prio=TaskPriority.medium, age=0):
            t = Task(
                project_id=project.id,
                title=title,
                status_id=cols[col].id,
                priority=prio,
                author_id=admin.id,
                position=float(len(title)),
                due_date=due,
                created_at=now - timedelta(days=age),
            )
            db.add(t)
            await db.flush()
            for u in who:
                db.add(TaskAssignee(task_id=t.id, user_id=u.id))
            return t

        far = now + timedelta(days=20)
        tasks = {
            "overdue": await task("Просрочена", [member], due=now - timedelta(days=1)),
            "soon": await task("Скоро срок", [member], col=1, due=now + timedelta(days=1)),
            "later": await task("Позже", [member], due=now + timedelta(days=5)),
            "urgent": await task("Срочная без срока", [member], prio=TaskPriority.urgent),
            "low": await task("Неважная", [member], prio=TaskPriority.low),
            "far": await task("Далёкий срок", [member], due=far, col=2),
            "done": await task("Уже готова", [member], col=3),
            "admin": await task("Задача админа", [admin, demo]),
            "viewer": await task("Задача наблюдателя", [viewer]),
        }
        await db.commit()
        return SimpleNamespace(
            project_id=project.id,
            cols=[c.id for c in cols],
            admin=admin,
            member=member,
            idle=idle,
            viewer=viewer,
            demo=demo,
            tasks={k: v.id for k, v in tasks.items()},
        )


async def _checkins(project_id):
    async with TestSession() as db:
        rows = (
            await db.scalars(select(RhythmCheckin).where(RhythmCheckin.project_id == project_id))
        ).all()
        out = {}
        for c in rows:
            items = (
                await db.scalars(
                    select(RhythmCheckinItem.task_id)
                    .where(RhythmCheckinItem.checkin_id == c.id)
                    .order_by(RhythmCheckinItem.position)
                )
            ).all()
            out[c.user_id] = (c, list(items))
        return out


@pytest.mark.asyncio
async def test_generation_picks_top5_once_per_day(settings, caplog):
    w = await _world()
    with caplog.at_level(logging.INFO, logger="app.services.rhythm_service"):
        first = await run_rhythm_pass(settings, now=MONDAY_1030_MSK)
    assert first["created"] == 2  # member + admin; idle (no tasks), viewer, demo — none
    assert "rhythm pass ok" in caplog.text
    # No personal data in loop logs
    assert "Участник" not in caplog.text and "@example.com" not in caplog.text

    rows = await _checkins(w.project_id)
    assert set(rows) == {w.member.id, w.admin.id}
    checkin, items = rows[w.member.id]
    assert checkin.date == date(2026, 11, 16)
    assert checkin.status == "pending"
    t = w.tasks
    # overdue → nearest deadline → by priority; max 5; done tasks excluded
    assert items == [t["overdue"], t["soon"], t["later"], t["far"], t["urgent"]]

    # Restart / second pass the same day: no duplicates
    second = await run_rhythm_pass(settings, now=MONDAY_1030_MSK + timedelta(minutes=30))
    assert second["created"] == 0
    async with TestSession() as db:
        n = await db.scalar(
            select(func.count()).select_from(RhythmCheckin).where(
                RhythmCheckin.project_id == w.project_id
            )
        )
        assert n == 2
        notes = await db.scalar(
            select(func.count()).select_from(Notification).where(
                Notification.user_id == w.member.id, Notification.kind == "rhythm_checkin"
            )
        )
        assert notes == 1

    # Next working day: new check-in, yesterday's unanswered one becomes skipped
    await run_rhythm_pass(settings, now=MONDAY_1030_MSK + timedelta(days=1))
    async with TestSession() as db:
        old = await db.get(RhythmCheckin, checkin.id)
        assert old.status == "skipped"


@pytest.mark.asyncio
async def test_no_checkins_outside_window_or_on_weekend(settings):
    w = await _world()
    assert (await run_rhythm_pass(settings, now=MONDAY_1030_MSK - timedelta(hours=2)))[
        "created"
    ] == 0
    assert (await run_rhythm_pass(settings, now=MONDAY_1030_MSK + timedelta(days=5)))[
        "created"
    ] == 0
    assert await _checkins(w.project_id) == {}


# ------------------------------------------------------------------ API helpers


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


async def _today_world(settings, monkeypatch) -> SimpleNamespace:
    """A world whose check-in is for the real 'today' (any local time qualifies)."""
    monkeypatch.setattr(settings, "RHYTHM_WINDOW_HOURS", 24)
    w = await _world(rhythm_time=time(0, 0), days=[1, 2, 3, 4, 5, 6, 7])
    await run_rhythm_pass(settings)
    rows = await _checkins(w.project_id)
    w.checkin_id = rows[w.member.id][0].id
    return w


async def _task(task_id):
    async with TestSession() as db:
        return await db.get(Task, task_id)


@pytest.mark.asyncio
async def test_answers_move_tasks_and_set_blocked(client, settings, monkeypatch):
    w = await _today_world(settings, monkeypatch)
    h = await _login(client, w.member)
    t = w.tasks

    cur = await client.get("/api/v1/rhythm/checkins/current")
    assert cur.status_code == 200, cur.text
    body = cur.json()
    assert body["pending"] == 1
    assert body["checkins"][0]["id"] == str(w.checkin_id)
    assert len(body["checkins"][0]["items"]) == 5

    r = await client.post(
        f"/api/v1/rhythm/checkins/{w.checkin_id}/answer",
        headers=h,
        json={
            "answers": [
                {"task_id": str(t["overdue"]), "answer": "done"},
                {"task_id": str(t["soon"]), "answer": "in_progress"},  # already in column 2
                {"task_id": str(t["later"]), "answer": "in_progress"},  # column 1 → 2
                {"task_id": str(t["far"]), "answer": "blocked", "reason": "Ждём подпись"},
            ]
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["checkin"]["status"] == "pending"  # one task still unanswered

    done = await _task(t["overdue"])
    assert done.status_id == w.cols[3] and done.closed_at is not None
    assert (await _task(t["soon"])).status_id == w.cols[1]
    assert (await _task(t["later"])).status_id == w.cols[1]
    far = await _task(t["far"])
    assert far.status_id == w.cols[2]
    assert far.blocked_at is not None and far.blocked_reason == "Ждём подпись"

    # «Застряла» is visible on the card (task API)
    got = (await client.get(f"/api/v1/tasks/{t['far']}")).json()["task"]
    assert got["blocked_reason"] == "Ждём подпись"
    assert got["blocked_by"]["name"] == "Участник Один"

    # History: check-in answers by the user + regular moves
    act = (await client.get(f"/api/v1/tasks/{t['far']}/activity")).json()
    items = act.get("items", act)
    assert any("застряла — «Ждём подпись»" in (a.get("summary") or "") for a in items)
    act_done = (await client.get(f"/api/v1/tasks/{t['overdue']}/activity")).json()
    summaries = [a.get("summary") for a in act_done.get("items", act_done)]
    assert "отметил(а) в чек-ине: сделано" in summaries
    assert any("перенёс(ла)" in (s or "") for s in summaries)

    # Answering the last task closes the check-in
    r = await client.post(
        f"/api/v1/rhythm/checkins/{w.checkin_id}/answer",
        headers=h,
        json={"answers": [{"task_id": str(t["urgent"]), "answer": "in_progress"}]},
    )
    assert r.json()["checkin"]["status"] == "answered"

    # Blocked flag is cleared by the next move…
    mv = await client.post(
        f"/api/v1/tasks/{t['far']}/move",
        headers=h,
        json={"status_id": str(w.cols[1]), "position": 0},
    )
    assert mv.status_code == 200, mv.text
    assert mv.json()["task"]["blocked_at"] is None


@pytest.mark.asyncio
async def test_blocked_cleared_by_in_progress_answer(client, settings, monkeypatch):
    w = await _today_world(settings, monkeypatch)
    h = await _login(client, w.member)
    url = f"/api/v1/rhythm/checkins/{w.checkin_id}/answer"
    far = str(w.tasks["far"])
    await client.post(url, headers=h, json={"answers": [{"task_id": far, "answer": "blocked"}]})
    assert (await _task(w.tasks["far"])).blocked_at is not None
    await client.post(
        url, headers=h, json={"answers": [{"task_id": far, "answer": "in_progress"}]}
    )
    t = await _task(w.tasks["far"])
    assert t.blocked_at is None and t.blocked_reason is None


@pytest.mark.asyncio
async def test_access_rules(client, settings, monkeypatch):
    w = await _today_world(settings, monkeypatch)
    url = f"/api/v1/rhythm/checkins/{w.checkin_id}"
    body = {"answers": [{"task_id": str(w.tasks["overdue"]), "answer": "done"}]}

    # Someone else's check-in: not visible, cannot answer
    async with await _client() as other:
        h = await _login(other, w.admin)
        assert (await other.get(url)).status_code == 404
        assert (await other.post(f"{url}/answer", headers=h, json=body)).status_code == 404
        # Task outside the check-in
        own = (await _checkins(w.project_id))[w.admin.id][0].id
        bad = await other.post(
            f"/api/v1/rhythm/checkins/{own}/answer",
            headers=h,
            json={"answers": [{"task_id": str(w.tasks["overdue"]), "answer": "done"}]},
        )
        assert bad.status_code == 400

    h = await _login(client, w.member)
    # No longer an assignee → 403, task untouched
    async with TestSession() as db:
        row = await db.scalar(
            select(TaskAssignee).where(
                TaskAssignee.task_id == w.tasks["overdue"], TaskAssignee.user_id == w.member.id
            )
        )
        await db.delete(row)
        db.add(TaskAssignee(task_id=w.tasks["overdue"], user_id=w.admin.id))
        await db.commit()
    r = await client.post(f"{url}/answer", headers=h, json=body)
    assert r.status_code == 403
    assert (await _task(w.tasks["overdue"])).closed_at is None

    # Removed from the project → 403
    async with TestSession() as db:
        m = await db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == w.project_id, ProjectMember.user_id == w.member.id
            )
        )
        await db.delete(m)
        await db.commit()
    assert (await client.get(url)).status_code == 403
    assert (await client.get("/api/v1/rhythm/checkins/current")).json()["checkins"] == []


@pytest.mark.asyncio
async def test_push_answer_token(client, settings, monkeypatch):
    sent: list[dict] = []

    async def fake_fcm(db, s, *, user_ids, title, body, data=None, **kw):
        sent.append({"data": data, **kw})

    from app.services import fcm_service

    monkeypatch.setattr(fcm_service, "send_fcm_to_users", fake_fcm)
    w = await _today_world(settings, monkeypatch)
    push = next(p for p in sent if p["data"]["checkin_id"] == str(w.checkin_id))
    assert push["apns_category"] == "TAKT_CHECKIN_MANY"
    assert push["android_data_only"] is True
    token = push["data"]["action_token"]

    payload = {
        "checkin_id": str(w.checkin_id),
        "task_id": str(w.tasks["overdue"]),
        "answer": "done",
        "token": "x" * 32,
    }
    assert (await client.post("/api/v1/rhythm/push-answer", json=payload)).status_code == 403
    payload["token"] = token
    ok = await client.post("/api/v1/rhythm/push-answer", json=payload)
    assert ok.status_code == 200, ok.text
    assert (await _task(w.tasks["overdue"])).status_id == w.cols[3]

    # Token is bound to this check-in: another one → 403
    other = (await _checkins(w.project_id))[w.admin.id][0].id
    payload.update(checkin_id=str(other), task_id=str(w.tasks["admin"]))
    assert (await client.post("/api/v1/rhythm/push-answer", json=payload)).status_code == 403

    # Yesterday's check-in can't be answered from an old notification
    async with TestSession() as db:
        c = await db.get(RhythmCheckin, w.checkin_id)
        c.date = c.date - timedelta(days=1)
        await db.commit()
    payload.update(checkin_id=str(w.checkin_id), task_id=str(w.tasks["soon"]))
    assert (await client.post("/api/v1/rhythm/push-answer", json=payload)).status_code == 409


@pytest.mark.asyncio
async def test_single_task_push_uses_one_task_category(settings, monkeypatch):
    sent: list[dict] = []

    async def fake_fcm(db, s, *, user_ids, title, body, data=None, **kw):
        sent.append({"title": title, "body": body, "data": data, **kw})

    from app.services import fcm_service

    monkeypatch.setattr(fcm_service, "send_fcm_to_users", fake_fcm)
    w = await _world()
    await run_rhythm_pass(settings, now=MONDAY_1030_MSK)
    admin_push = next(p for p in sent if p["data"]["task_count"] == "1")
    assert admin_push["apns_category"] == "TAKT_CHECKIN_ONE"
    assert admin_push["data"]["task_id"] == str(w.tasks["admin"])
    assert admin_push["body"] == "Задача админа"


@pytest.mark.asyncio
async def test_project_rhythm_settings(client):
    await client.post(
        "/api/v1/auth/login", json={"email": "admin@test.com", "password": "Admin123!Test"}
    )
    h = {"X-CSRF-Token": client.cookies.get("csrf_token") or ""}
    created = await client.post(
        "/api/v1/projects",
        headers=h,
        json={"name": "Новый", "color": "#315F72", "icon": "folder", "member_ids": []},
    )
    project = created.json()["project"]
    # New projects: rhythm on, 10:00 Moscow, Mon–Fri
    assert project["rhythm"] == {
        "enabled": True,
        "time": "10:00",
        "timezone": MSK,
        "days": [1, 2, 3, 4, 5],
    }
    pid = project["id"]
    r = await client.patch(
        f"/api/v1/projects/{pid}",
        headers=h,
        json={
            "rhythm_enabled": False,
            "rhythm_time": "09:30",
            "rhythm_timezone": "Asia/Yekaterinburg",
            "rhythm_days": [5, 1, 1],
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["project"]["rhythm"] == {
        "enabled": False,
        "time": "09:30",
        "timezone": "Asia/Yekaterinburg",
        "days": [1, 5],
    }
    bad_tz = await client.patch(
        f"/api/v1/projects/{pid}", headers=h, json={"rhythm_timezone": "Mars/Base"}
    )
    assert bad_tz.status_code == 400
    bad_days = await client.patch(f"/api/v1/projects/{pid}", headers=h, json={"rhythm_days": []})
    assert bad_days.status_code == 422
    bad_time = await client.patch(
        f"/api/v1/projects/{pid}", headers=h, json={"rhythm_time": "25:00"}
    )
    assert bad_time.status_code == 422

    # Only project admins may change rhythm settings
    async with TestSession() as db:
        member = await _user(db, "rhythm-member@example.com", "Участник")
        db.add(
            ProjectMember(
                project_id=uuid.UUID(pid), user_id=member.id, role=ProjectMemberRole.member
            )
        )
        await db.commit()
    async with await _client() as m:
        mh = await _login(m, member)
        denied = await m.patch(f"/api/v1/projects/{pid}", headers=mh, json={"rhythm_enabled": True})
        assert denied.status_code == 403


@pytest.mark.asyncio
async def test_loop_iteration_creates_checkins(settings, monkeypatch):
    """Through rhythm_loop itself: one iteration creates today's check-ins."""
    monkeypatch.setattr(settings, "RHYTHM_ENABLED", True)
    monkeypatch.setattr(settings, "RHYTHM_INTERVAL_SECONDS", 60)
    monkeypatch.setattr(settings, "RHYTHM_WINDOW_HOURS", 24)
    w = await _world(rhythm_time=time(0, 0), days=[1, 2, 3, 4, 5, 6, 7])
    stop = asyncio.Event()
    task = asyncio.create_task(rhythm_loop(stop))
    for _ in range(100):
        if await _checkins(w.project_id):
            break
        await asyncio.sleep(0.05)
    stop.set()
    await asyncio.wait_for(task, timeout=5)
    assert set(await _checkins(w.project_id)) == {w.member.id, w.admin.id}


@pytest.mark.asyncio
async def test_activity_rows_written_for_checkin(settings, monkeypatch, client):
    w = await _today_world(settings, monkeypatch)
    h = await _login(client, w.member)
    await client.post(
        f"/api/v1/rhythm/checkins/{w.checkin_id}/answer",
        headers=h,
        json={"answers": [{"task_id": str(w.tasks["later"]), "answer": "in_progress"}]},
    )
    async with TestSession() as db:
        rows = (
            await db.execute(
                select(ActivityLog.action, ActivityLog.field, ActivityLog.user_id).where(
                    ActivityLog.task_id == w.tasks["later"]
                )
            )
        ).all()
    actions = {(a, f) for a, f, _u in rows}
    assert ("checkin", "in_progress") in actions
    assert ("moved", "status_id") in actions
    assert all(u == w.member.id for _a, _f, u in rows)


@pytest.mark.asyncio
async def test_manual_start_creates_today_checkin_without_push(client, settings, monkeypatch):
    sent: list = []

    async def fake_fcm(*a, **kw):
        sent.append(kw)

    async def fake_webpush(*a, **kw):
        sent.append(kw)

    from app.services import fcm_service, push_service

    monkeypatch.setattr(fcm_service, "send_fcm_to_users", fake_fcm)
    monkeypatch.setattr(push_service, "send_push_to_users", fake_webpush)
    # Outside the loop window — only a manual start can create today's check-in.
    w = await _world(rhythm_time=time(23, 59), days=[1, 2, 3, 4, 5, 6, 7])
    h = await _login(client, w.member)

    cur = (await client.get("/api/v1/rhythm/checkins/current")).json()
    assert cur["checkins"] == []
    assert cur["startable_project_ids"] == [str(w.project_id)]

    url = "/api/v1/rhythm/checkins/start"
    r = await client.post(url, headers=h, params={"project_id": str(w.project_id)})
    assert r.status_code == 200, r.text
    first = r.json()["checkin"]
    assert first["status"] == "pending"
    # Same picking as the loop: overdue → nearest deadline → priority, max 5
    t = w.tasks
    assert [i["task_id"] for i in first["items"]] == [
        str(t["overdue"]), str(t["soon"]), str(t["later"]), str(t["far"]), str(t["urgent"])
    ]
    assert sent == []  # no push for a manual start

    again = await client.post(url, headers=h, params={"project_id": str(w.project_id)})
    assert again.json()["checkin"]["id"] == first["id"]  # unique user+project+date
    cur = (await client.get("/api/v1/rhythm/checkins/current")).json()
    assert cur["pending"] == 1 and cur["startable_project_ids"] == []


@pytest.mark.asyncio
async def test_manual_start_access_and_conditions(client, settings):
    w = await _world(rhythm_time=time(23, 59), days=[1, 2, 3, 4, 5, 6, 7])
    params = {"project_id": str(w.project_id)}
    url = "/api/v1/rhythm/checkins/start"

    async with await _client() as c:
        h = await _login(c, w.viewer)  # viewer can't answer → can't start
        assert (await c.post(url, headers=h, params=params)).status_code == 403
    async with await _client() as c:
        h = await _login(c, w.idle)  # member without open tasks
        r = await c.post(url, headers=h, params=params)
        assert r.status_code == 409 and r.json()["detail"]["error"]["code"] == "no_open_tasks"
    async with TestSession() as db:
        outsider = await _user(db, "outsider-rhythm@example.com", "Чужой")
        await db.commit()
    async with await _client() as c:
        h = await _login(c, outsider)
        assert (await c.post(url, headers=h, params=params)).status_code == 403

    async with TestSession() as db:
        p = await db.get(Project, w.project_id)
        p.rhythm_enabled = False
        await db.commit()
    h = await _login(client, w.member)
    r = await client.post(url, headers=h, params=params)
    assert r.status_code == 409 and r.json()["detail"]["error"]["code"] == "rhythm_off"
    cur = (await client.get("/api/v1/rhythm/checkins/current")).json()
    assert cur["startable_project_ids"] == []
