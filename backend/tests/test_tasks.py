import pytest
from httpx import AsyncClient

from tests.conftest import current_user_id


async def _login_admin(client: AsyncClient):
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    csrf = client.cookies.get("csrf_token")
    return {"X-CSRF-Token": csrf or ""}


@pytest.mark.asyncio
async def test_status_closed_at(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    backlog = next(s for s in statuses if not s["is_done"])
    done = next(s for s in statuses if s["is_done"])
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "T", "status_id": backlog["id"], "assignee_ids": [uid]},
    )
    task = created.json()["task"]
    assert task["closed_at"] is None
    moved = await client.post(
        f"/api/v1/tasks/{task['id']}/move",
        headers=headers,
        json={"status_id": done["id"], "position": 1000},
    )
    assert moved.json()["task"]["closed_at"] is not None
    back = await client.patch(
        f"/api/v1/tasks/{task['id']}",
        headers=headers,
        json={"status_id": backlog["id"]},
    )
    assert back.json()["task"]["closed_at"] is None


@pytest.mark.asyncio
async def test_create_requires_assignee(client: AsyncClient):
    headers = await _login_admin(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    backlog = next(s for s in statuses if not s["is_done"])

    missing = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "No assignee", "status_id": backlog["id"]},
    )
    assert missing.status_code == 422

    empty = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "Empty assignees", "status_id": backlog["id"], "assignee_ids": []},
    )
    assert empty.status_code in (400, 422)

    uid = await current_user_id(client)
    ok = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "With assignee",
            "status_id": backlog["id"],
            "assignee_ids": [uid],
        },
    )
    assert ok.status_code == 200, ok.text
    assert len(ok.json()["task"]["assignees"]) == 1


@pytest.mark.asyncio
async def test_update_rejects_empty_assignees(client: AsyncClient):
    headers = await _login_admin(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    backlog = next(s for s in statuses if not s["is_done"])
    uid = await current_user_id(client)
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Keep assignee",
            "status_id": backlog["id"],
            "assignee_ids": [uid],
        },
    )
    assert created.status_code == 200, created.text
    task_id = created.json()["task"]["id"]

    empty = await client.patch(
        f"/api/v1/tasks/{task_id}",
        headers=headers,
        json={"assignee_ids": []},
    )
    assert empty.status_code in (400, 422)

    kept = await client.get(f"/api/v1/tasks/{task_id}")
    assert kept.status_code == 200
    assert len(kept.json()["task"]["assignees"]) == 1


@pytest.mark.asyncio
async def test_excel_export(client: AsyncClient):
    await _login_admin(client)
    r = await client.get("/api/v1/reports/export")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    assert len(r.content) > 1000
