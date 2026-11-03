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
async def test_new_task_appears_at_top_of_nonempty_column(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    col = next(s for s in statuses if not s["is_done"])

    first = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Older card",
            "status_id": col["id"],
            "priority": "medium",
            "assignee_ids": [uid],
        },
    )
    assert first.status_code == 200, first.text
    older = first.json()["task"]

    second = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Newest card",
            "status_id": col["id"],
            "priority": "high",
            "assignee_ids": [uid],
        },
    )
    assert second.status_code == 200, second.text
    newest = second.json()["task"]

    assert newest["position"] < older["position"]

    listed = await client.get("/api/v1/tasks", params={"status_id": col["id"], "page_size": 50})
    assert listed.status_code == 200
    items = listed.json()["items"]
    ids = [t["id"] for t in items if t["status_id"] == col["id"]]
    assert ids[0] == newest["id"]
    assert older["id"] in ids
    assert ids.index(newest["id"]) < ids.index(older["id"])
