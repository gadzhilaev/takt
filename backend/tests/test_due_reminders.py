import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models.notification import Notification
from app.models.task import Task
from app.services.due_reminder_service import process_due_reminders
from tests.conftest import current_user_id


async def _login_admin(client: AsyncClient):
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    csrf = client.cookies.get("csrf_token")
    return {"X-CSRF-Token": csrf or ""}


@pytest.mark.asyncio
async def test_clear_due_date(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    backlog = next(s for s in statuses if not s["is_done"])
    due = (datetime.now(UTC) + timedelta(days=2)).isoformat()
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "With due",
            "status_id": backlog["id"],
            "assignee_ids": [uid],
            "due_date": due,
        },
    )
    assert created.status_code == 200, created.text
    task = created.json()["task"]
    assert task["due_date"] is not None

    cleared = await client.patch(
        f"/api/v1/tasks/{task['id']}",
        headers=headers,
        json={"due_date": None},
    )
    assert cleared.status_code == 200, cleared.text
    assert cleared.json()["task"]["due_date"] is None


@pytest.mark.asyncio
async def test_due_soon_and_overdue_once(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    backlog = next(s for s in statuses if not s["is_done"])
    done = next(s for s in statuses if s["is_done"])
    settings = get_settings()

    soon_due = datetime.now(UTC) + timedelta(hours=2)
    overdue_due = datetime.now(UTC) - timedelta(hours=1)
    done_due = datetime.now(UTC) - timedelta(hours=2)

    soon = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Soon",
            "status_id": backlog["id"],
            "assignee_ids": [uid],
            "due_date": soon_due.isoformat(),
        },
    )
    assert soon.status_code == 200, soon.text
    soon_id = soon.json()["task"]["id"]

    overdue = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Overdue",
            "status_id": backlog["id"],
            "assignee_ids": [uid],
            "due_date": overdue_due.isoformat(),
        },
    )
    assert overdue.status_code == 200, overdue.text
    overdue_id = overdue.json()["task"]["id"]

    done_task = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Done overdue",
            "status_id": done["id"],
            "assignee_ids": [uid],
            "due_date": done_due.isoformat(),
        },
    )
    assert done_task.status_code == 200, done_task.text
    done_id = done_task.json()["task"]["id"]

    first = await process_due_reminders(settings=settings)
    assert first["due_soon"] == 1
    assert first["overdue"] == 1

    second = await process_due_reminders(settings=settings)
    assert second["due_soon"] == 0
    assert second["overdue"] == 0

    async with AsyncSessionLocal() as db:
        notes = (
            await db.execute(
                select(Notification).where(
                    Notification.task_id.in_([soon_id, overdue_id, done_id])
                )
            )
        ).scalars().all()
        kinds = {(str(n.task_id), n.kind) for n in notes}
        assert (soon_id, "task_due_soon") in kinds
        assert (overdue_id, "task_overdue") in kinds
        assert not any(str(n.task_id) == done_id for n in notes)

        # Changing due_date resets notify flags.
        task = await db.get(Task, uuid.UUID(soon_id))
        assert task is not None
        assert task.due_soon_notified_at is not None

    new_due = (datetime.now(UTC) + timedelta(hours=3)).isoformat()
    patched = await client.patch(
        f"/api/v1/tasks/{soon_id}",
        headers=headers,
        json={"due_date": new_due},
    )
    assert patched.status_code == 200, patched.text

    async with AsyncSessionLocal() as db:
        task = await db.get(Task, uuid.UUID(soon_id))
        assert task is not None
        assert task.due_soon_notified_at is None
        assert task.overdue_notified_at is None

    third = await process_due_reminders(settings=settings)
    assert third["due_soon"] == 1
