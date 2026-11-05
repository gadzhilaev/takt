from datetime import UTC, datetime, timedelta

import pytest

from app.models.task import TaskPriority
from app.services.due_urgency_service import (
    escalate_priority,
    remaining_ratio,
    suggested_priority,
)


def test_remaining_ratio_and_thresholds():
    basis = datetime(2026, 1, 1, 12, 0, tzinfo=UTC)
    due = basis + timedelta(days=10)  # 10-day window

    # 50% left → no auto bump
    now = basis + timedelta(days=5)
    assert 0.49 < remaining_ratio(due, basis, now) < 0.51
    assert suggested_priority(due, basis, now) is None

    # 35% left → high
    now = due - timedelta(days=3.5)
    assert suggested_priority(due, basis, now) == TaskPriority.high

    # 10% left → urgent
    now = due - timedelta(days=1)
    assert suggested_priority(due, basis, now) == TaskPriority.urgent

    # overdue → urgent
    now = due + timedelta(hours=1)
    assert remaining_ratio(due, basis, now) < 0
    assert suggested_priority(due, basis, now) == TaskPriority.urgent


def test_escalate_never_downgrades():
    assert escalate_priority(TaskPriority.medium, TaskPriority.high) == TaskPriority.high
    assert escalate_priority(TaskPriority.urgent, TaskPriority.high) is None
    assert escalate_priority(TaskPriority.high, None) is None


@pytest.mark.asyncio
async def test_auto_urgency_api(client):
    from httpx import AsyncClient

    from tests.conftest import current_user_id

    assert isinstance(client, AsyncClient)
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    headers = {"X-CSRF-Token": client.cookies.get("csrf_token") or ""}
    uid = await current_user_id(client)
    projects = (await client.get("/api/v1/projects")).json()["items"]
    project = projects[0]
    assert project["auto_urgency_from_due"] is True

    toggled = await client.patch(
        f"/api/v1/projects/{project['id']}",
        headers=headers,
        json={"auto_urgency_from_due": False},
    )
    assert toggled.status_code == 200, toggled.text
    assert toggled.json()["project"]["auto_urgency_from_due"] is False

    await client.patch(
        f"/api/v1/projects/{project['id']}",
        headers=headers,
        json={"auto_urgency_from_due": True},
    )

    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    backlog = next(s for s in statuses if not s["is_done"])
    # Due in 1 hour → window short; create with medium, should escalate toward urgent.
    due = (datetime.now(UTC) + timedelta(hours=1)).isoformat()
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Soon due",
            "status_id": backlog["id"],
            "assignee_ids": [uid],
            "priority": "medium",
            "due_date": due,
        },
    )
    assert created.status_code == 200, created.text
    # With basis≈now and due in 1h, remaining≈100% → no escalate yet.
    assert created.json()["task"]["priority"] == "medium"
