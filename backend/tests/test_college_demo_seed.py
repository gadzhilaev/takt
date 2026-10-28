import pytest
from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import get_db
from app.models.project import Project, ProjectMember
from app.models.task import Task
from app.models.user import User, UserRole
from app.services.college_demo_seed import COLLEGE_PROJECT_NAME, COLLEGE_TASKS, DEMO_STAFF, seed_college_demo


@pytest.mark.asyncio
async def test_college_demo_seed_idempotent(client, admin_client):
    """Seed creates staff+tasks once; second run does not duplicate."""
    # Create demo viewer matching settings
    settings = get_settings()
    email = (settings.DEMO_USER_EMAIL or "demo@example.com").strip().lower()
    # Use test DB session via override — talk through API register if needed
    from tests.conftest import TestSession

    async with TestSession() as db:
        existing = await db.scalar(select(User).where(User.email == email))
        if not existing:
            db.add(
                User(
                    email=email,
                    name="Демо пользователь",
                    role=UserRole.member,
                    password_hash=hash_password("DemoSeedPass123!"),
                    is_active=True,
                    is_demo=True,
                    must_change_password=False,
                )
            )
            await db.commit()

        r1 = await seed_college_demo(db, settings)
        assert r1["staff"] == len(DEMO_STAFF)
        assert r1["tasks_created"] + r1["tasks_existing"] == len(COLLEGE_TASKS)
        assert r1["notifications"] >= 3

        r2 = await seed_college_demo(db, settings)
        assert r2["tasks_created"] == 0
        assert r2["tasks_existing"] == len(COLLEGE_TASKS)
        assert r2["staff"] == len(DEMO_STAFF)

        project = await db.scalar(
            select(Project).where(Project.name == COLLEGE_PROJECT_NAME, Project.is_demo.is_(True))
        )
        assert project is not None
        members = (
            await db.scalars(select(ProjectMember).where(ProjectMember.project_id == project.id))
        ).all()
        # demo viewer + 8 staff
        assert len(members) == 1 + len(DEMO_STAFF)

        live = await db.scalar(
            select(func.count())
            .select_from(Task)
            .where(Task.project_id == project.id, Task.deleted_at.is_(None))
        )
        # COLLEGE_TASKS plus possible extra assignee-only rows still same titles count
        assert live >= len(COLLEGE_TASKS)

    # Staff cannot log in
    staff_email = DEMO_STAFF[0][2]
    bad = await client.post(
        "/api/v1/auth/login",
        json={"email": staff_email, "password": "anything"},
    )
    assert bad.status_code == 401

    # Admin must not see college project without membership
    lst = await admin_client.get("/api/v1/projects")
    assert lst.status_code == 200
    names = [p["name"] for p in lst.json()["items"]]
    assert COLLEGE_PROJECT_NAME not in names
