"""Seed для аккаунта App Review: объём данных, идемпотентность, отсутствие dev-задач."""

import re
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select

from app.models.notification import Notification
from app.models.project import Project, ProjectMember
from app.models.task import ActivityLog, Attachment, Comment, Task, TaskAssignee
from app.models.user import User
from app.services.attachment_service import attachment_path
from app.services.review_account_seed import (
    REVIEW_PROJECTS,
    ReviewSeedRefused,
    plan_review_seed,
    seed_review_account,
)
from tests.conftest import TestSession

EMAIL = "reviewer@example.com"
PASSWORD = "Review-Pass-123!"
FORBIDDEN = re.compile(r"takt|kanban|mobile|web|карточк|доск|e2e", re.IGNORECASE)


async def _counts(db, user_id):
    project_ids = (
        await db.scalars(select(ProjectMember.project_id).where(ProjectMember.user_id == user_id))
    ).all()
    task_ids = (
        await db.scalars(
            select(Task.id).where(Task.project_id.in_(project_ids), Task.deleted_at.is_(None))
        )
    ).all()

    async def n(model, col):
        return await db.scalar(select(func.count()).select_from(model).where(col.in_(task_ids)))

    return {
        "projects": len(project_ids),
        "tasks": len(task_ids),
        "comments": await n(Comment, Comment.task_id),
        "attachments": await n(Attachment, Attachment.task_id),
        "activity": await n(ActivityLog, ActivityLog.task_id),
        "notifications": await db.scalar(
            select(func.count()).select_from(Notification).where(Notification.user_id == user_id)
        ),
    }


@pytest.mark.asyncio
async def test_seed_creates_account_and_is_idempotent(client: AsyncClient):
    async with TestSession() as db:
        r1 = await seed_review_account(db, email=EMAIL, password=PASSWORD)
    assert r1["user_created"] is True
    assert 2 <= len(r1["projects"]) <= 3
    assert 15 <= r1["tasks_created"] <= 25

    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == EMAIL))
        assert me is not None and me.is_demo is False
        first = await _counts(db, me.id)

        tasks = (
            await db.scalars(
                select(Task).join(ProjectMember, ProjectMember.project_id == Task.project_id)
                .where(ProjectMember.user_id == me.id)
            )
        ).all()
        now = datetime.now(UTC)
        assert any(t.due_date and t.due_date < now and t.closed_at is None for t in tasks)
        assert any(
            t.due_date and 0 < (t.due_date - now).total_seconds() < 48 * 3600 for t in tasks
        )
        assert {t.priority.value for t in tasks} >= {"low", "medium", "high", "urgent"}
        for t in tasks:
            assert not FORBIDDEN.search(t.title), t.title
            n_assignees = await db.scalar(
                select(func.count()).select_from(TaskAssignee).where(TaskAssignee.task_id == t.id)
            )
            assert n_assignees >= 1

        for att in (await db.scalars(select(Attachment))).all():
            assert attachment_path(att).exists()

        staff = (
            await db.scalars(select(User).where(User.email.like("demo.review.%")))
        ).all()
        assert staff and all(u.is_demo for u in staff)
        projects = (
            await db.scalars(
                select(Project).join(ProjectMember).where(ProjectMember.user_id == me.id)
            )
        ).all()
        assert {p.name for p in projects} == {p.name for p in REVIEW_PROJECTS}

    assert first["comments"] > 0
    assert first["attachments"] > 0
    assert first["activity"] > first["tasks"]
    assert first["notifications"] >= 3

    # Повторный запуск без пароля: ничего не дублируется.
    async with TestSession() as db:
        r2 = await seed_review_account(db, email=EMAIL)
    assert r2["user_created"] is False
    assert r2["tasks_created"] == 0
    assert r2["tasks_updated"] == r1["tasks_created"]
    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == EMAIL))
        assert await _counts(db, me.id) == first

    # Ревьюер может войти, видит проекты и задачи через API.
    login = await client.post("/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD})
    assert login.status_code == 200, login.text
    projects = await client.get("/api/v1/projects")
    assert projects.status_code == 200
    body = projects.json()
    items = body if isinstance(body, list) else body.get("items", [])
    assert len(items) == len(REVIEW_PROJECTS)


@pytest.mark.asyncio
async def test_seed_requires_password_for_new_account():
    async with TestSession() as db:
        with pytest.raises(RuntimeError):
            await seed_review_account(db, email="nobody@example.com")


@pytest.mark.asyncio
async def test_seed_removes_reviewer_from_foreign_projects(client: AsyncClient):
    """Старый проект «Проверка магазина» исчезает; из общего проекта ревьюер выходит."""
    from app.core.security import hash_password
    from app.models.project import ProjectMemberRole

    email = "reviewer-old@example.com"
    async with TestSession() as db:
        me = User(email=email, name="Ревьюер", password_hash=hash_password("x" * 12))
        colleague = User(email="real-colleague@example.com", name="Коллега Реальный",
                         password_hash=hash_password("y" * 12))
        db.add_all([me, colleague])
        await db.flush()
        solo = Project(name="Проверка магазина", is_demo=False)
        shared = Project(name="Чужой рабочий проект", is_demo=False)
        db.add_all([solo, shared])
        await db.flush()
        db.add_all([
            ProjectMember(project_id=solo.id, user_id=me.id, role=ProjectMemberRole.admin),
            ProjectMember(project_id=shared.id, user_id=me.id, role=ProjectMemberRole.admin),
            ProjectMember(project_id=shared.id, user_id=colleague.id,
                          role=ProjectMemberRole.member),
        ])
        await db.commit()
        solo_id, shared_id, colleague_id = solo.id, shared.id, colleague.id

    # Без явного согласия трогать проекты с реальными людьми нельзя — ничего не меняется.
    async with TestSession() as db:
        with pytest.raises(ReviewSeedRefused, match="Чужой рабочий проект"):
            await seed_review_account(db, email=email)
    async with TestSession() as db:
        assert await db.get(Project, solo_id) is not None
        assert await db.scalar(
            select(func.count()).select_from(Project).where(Project.name == REVIEW_PROJECTS[0].name)
        ) == 0

    async with TestSession() as db:
        report = await seed_review_account(db, email=email, force_foreign_projects=True)
    assert {r["name"]: r["action"] for r in report["removed_projects"]} == {
        "Проверка магазина": "delete",
        "Чужой рабочий проект": "transfer",
    }

    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == email))
        assert await db.get(Project, solo_id) is None
        assert await db.get(Project, shared_id) is not None
        names = set(
            (
                await db.scalars(
                    select(Project.name).join(ProjectMember)
                    .where(ProjectMember.user_id == me.id)
                )
            ).all()
        )
        assert names == {p.name for p in REVIEW_PROJECTS}
        heir_role = await db.scalar(
            select(ProjectMember.role).where(
                ProjectMember.project_id == shared_id, ProjectMember.user_id == colleague_id
            )
        )
        assert heir_role == ProjectMemberRole.admin

    # Повторный запуск ничего больше не трогает.
    async with TestSession() as db:
        again = await seed_review_account(db, email=email)
    assert again["removed_projects"] == []


@pytest.mark.asyncio
async def test_plan_and_cli_dry_run_change_nothing():
    """plan_review_seed и CLI без --apply только печатают план."""
    import os
    import subprocess
    import sys
    from pathlib import Path

    from app.core.security import hash_password
    from app.models.project import ProjectMemberRole

    email = "reviewer-dry@example.com"
    async with TestSession() as db:
        me = User(email=email, name="Ревьюер", password_hash=hash_password("x" * 12))
        db.add(me)
        await db.flush()
        old = Project(name="Проверка магазина", is_demo=False)
        db.add(old)
        await db.flush()
        db.add(ProjectMember(project_id=old.id, user_id=me.id, role=ProjectMemberRole.admin))
        await db.commit()
        old_id = old.id

    async with TestSession() as db:
        plan = await plan_review_seed(db, email=email)
    assert plan["user_exists"] is True
    assert [(p["name"], p["action"]) for p in plan["foreign"]] == [("Проверка магазина", "delete")]
    assert plan["shared_with_real"] == []

    backend = Path(__file__).resolve().parents[1]
    out = subprocess.run(
        [sys.executable, "scripts/seed_review_account.py", "--email", email],
        cwd=backend, env=os.environ.copy(), capture_output=True, text=True, timeout=60,
    )
    assert out.returncode == 0, out.stderr
    assert "DRY-RUN" in out.stdout
    assert "«Проверка магазина»: проект будет удалён" in out.stdout

    async with TestSession() as db:
        assert await db.get(Project, old_id) is not None
        n = await db.scalar(
            select(func.count()).select_from(Project).where(Project.name == REVIEW_PROJECTS[0].name)
        )
        assert n == 0


@pytest.mark.asyncio
async def test_seed_turns_on_rhythm_and_creates_today_checkin():
    from datetime import time as dtime

    from app.models.rhythm import RhythmCheckin
    from app.models.team import TaskStatus
    from app.services.rhythm_service import local_today

    email = "reviewer-rhythm@example.com"
    async with TestSession() as db:
        r1 = await seed_review_account(db, email=email, password="Review-Pass-123!")
    assert r1["checkin"]["status"] == "pending" and r1["checkin"]["tasks"] >= 3
    assert r1["blocked_task"] == "Настроить проектор в актовом зале"

    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == email))
        projects = (
            await db.scalars(
                select(Project).join(ProjectMember).where(ProjectMember.user_id == me.id)
            )
        ).all()
        assert len(projects) == 3
        now = datetime.now(UTC)
        for p in projects:
            assert p.rhythm_enabled and p.rhythm_time == dtime(0, 5)
            assert p.rhythm_timezone == "Europe/Moscow" and p.rhythm_days == [1, 2, 3, 4, 5, 6, 7]
            open_mine = (
                await db.scalars(
                    select(Task)
                    .join(TaskAssignee, TaskAssignee.task_id == Task.id)
                    .join(TaskStatus, TaskStatus.id == Task.status_id)
                    .where(
                        Task.project_id == p.id,
                        TaskAssignee.user_id == me.id,
                        TaskStatus.is_done.is_(False),
                    )
                )
            ).all()
            assert 3 <= len(open_mine) <= 5, (p.name, len(open_mine))
            assert any(
                t.due_date and 0 < (t.due_date - now).total_seconds() < 72 * 3600 for t in open_mine
            ), p.name
        checkins = (
            await db.scalars(
                select(RhythmCheckin).where(
                    RhythmCheckin.user_id == me.id, RhythmCheckin.status == "pending"
                )
            )
        ).all()
        assert len(checkins) == 1  # past ones are answered/skipped
        c = checkins[0]
        project = await db.get(Project, c.project_id)
        assert project.name == "Цифровые сервисы колледжа"
        assert c.date == local_today(project)
        blocked = await db.scalar(
            select(Task).where(Task.title == "Настроить проектор в актовом зале")
        )
        assert blocked.blocked_at is not None
        assert blocked.blocked_reason == "Ждём переходник HDMI от завхоза"

    # Повторный запуск в тот же день — тот же чек-ин, без дублей.
    async with TestSession() as db:
        r2 = await seed_review_account(db, email=email)
    assert r2["checkin"]["id"] == r1["checkin"]["id"]


@pytest.mark.asyncio
async def test_seed_gives_reviewer_non_empty_weekly_digest():
    from app.services.digest_service import build_digest

    email = "reviewer-digest@example.com"
    async with TestSession() as db:
        r1 = await seed_review_account(db, email=email, password="Review-Pass-123!")
    s = r1["digest"]
    assert s["done"] >= 2 and s["stuck"] >= 1 and s["overdue"] >= 1
    assert s["participation"] is not None and 50 <= s["participation"] < 100
    assert r1["past_checkins"] > 0

    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == email))
        roles = (
            await db.scalars(select(ProjectMember.role).where(ProjectMember.user_id == me.id))
        ).all()
        assert len(roles) == 3 and all(r.value == "admin" for r in roles)
        digests = (
            await db.scalars(
                select(Notification.title).where(
                    Notification.user_id == me.id, Notification.kind == "digest"
                )
            )
        ).all()
        assert len(digests) == 3 and all(t.startswith("Сводка за неделю:") for t in digests)
        project = await db.scalar(
            select(Project).where(Project.name == "Цифровые сервисы колледжа")
        )
        d = await build_digest(db, project, kind="week", include_members=True)
        assert d["bottleneck"] is not None
        assert d["rhythm"]["members_without_answer"]  # demo staff with skipped check-ins

    # Повторный запуск: без дублей прошлых чек-инов и сводок.
    async with TestSession() as db:
        r2 = await seed_review_account(db, email=email)
    assert r2["past_checkins"] == 0
    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == email))
        n = await db.scalar(
            select(func.count()).select_from(Notification).where(
                Notification.user_id == me.id, Notification.kind == "digest"
            )
        )
        assert n == 3
