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
from app.services.review_account_seed import REVIEW_PROJECTS, seed_review_account
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
