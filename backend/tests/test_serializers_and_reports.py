from uuid import uuid4

import pytest
from httpx import AsyncClient

from app.api.serializers import status_to_out
from app.models.team import TaskStatus
from app.schemas.task import ChecklistItemOut, StatusOut
from tests.conftest import current_user_id


async def _login_admin(client: AsyncClient):
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    csrf = client.cookies.get("csrf_token")
    return {"X-CSRF-Token": csrf or ""}


def test_status_out_from_uuid_orm_like():
    status = TaskStatus(
        id=uuid4(),
        name="Бэклог",
        color="#94a3b8",
        position=0,
        is_done=False,
    )
    out = StatusOut.model_validate(status)
    assert isinstance(out.id, str)
    assert out.id == str(status.id)
    assert status_to_out(status).id == str(status.id)


def test_checklist_out_coerces_uuid():
    item_id = uuid4()
    out = ChecklistItemOut.model_validate(
        {"id": item_id, "title": "x", "is_done": False, "position": 1.0}
    )
    assert out.id == str(item_id)


@pytest.mark.asyncio
async def test_list_statuses_ok(client: AsyncClient):
    await _login_admin(client)
    r = await client.get("/api/v1/settings/statuses")
    assert r.status_code == 200
    items = r.json()["items"]
    assert len(items) >= 1
    assert isinstance(items[0]["id"], str)


@pytest.mark.asyncio
async def test_list_and_create_task_ok(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    status_id = statuses[0]["id"]
    listed = await client.get("/api/v1/tasks?page_size=50")
    assert listed.status_code == 200
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Regression create",
            "status_id": status_id,
            "priority": "medium",
            "assignee_ids": [uid],
        },
    )
    assert created.status_code == 200, created.text
    task = created.json()["task"]
    assert task["title"] == "Regression create"
    assert isinstance(task["id"], str)
    assert task["status"] is None or isinstance(task["status"]["id"], str)


@pytest.mark.asyncio
async def test_reports_and_export_ok(client: AsyncClient):
    await _login_admin(client)
    report = await client.get("/api/v1/reports?preset=month")
    assert report.status_code == 200, report.text
    body = report.json()
    assert "metrics" in body
    assert "closed_by_day" in body
    by_status = body["metrics"]["by_status"]
    names = [n for n, _ in by_status]
    assert len(names) == len(set(names)), "by_status must aggregate duplicate status names"
    for emp in body.get("by_employee", []):
        assert emp["on_time_pct"] is None or isinstance(emp["on_time_pct"], (int, float))
    export = await client.get("/api/v1/reports/export?preset=month")
    assert export.status_code == 200, export.text
    cd = export.headers.get("content-disposition", "")
    assert "attachment" in cd
    assert "filename=" in cd
    assert export.headers["content-type"].startswith(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    assert len(export.content) > 500


@pytest.mark.asyncio
async def test_move_returns_fresh_nested_status(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    todo = next(s for s in statuses if not s["is_done"])
    done = next(s for s in statuses if s["is_done"])
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "Move nested status", "status_id": todo["id"], "assignee_ids": [uid]},
    )
    assert created.status_code == 200, created.text
    tid = created.json()["task"]["id"]
    moved = await client.post(
        f"/api/v1/tasks/{tid}/move",
        headers=headers,
        json={"status_id": done["id"], "position": 2048},
    )
    assert moved.status_code == 200, moved.text
    task = moved.json()["task"]
    assert task["status_id"] == done["id"]
    assert task["status"] is not None
    assert task["status"]["id"] == done["id"]
    assert task["status"]["name"] == done["name"]
    assert task["closed_at"] is not None
    reopened = await client.post(
        f"/api/v1/tasks/{tid}/move",
        headers=headers,
        json={"status_id": todo["id"], "position": 1024},
    )
    assert reopened.status_code == 200, reopened.text
    task2 = reopened.json()["task"]
    assert task2["status_id"] == todo["id"]
    assert task2["status"]["id"] == todo["id"]
    assert task2["status"]["name"] == todo["name"]
    assert task2["closed_at"] is None


@pytest.mark.asyncio
async def test_patch_saves_due_and_assignees(client: AsyncClient):
    headers = await _login_admin(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    users = (await client.get("/api/v1/users")).json()["items"]
    assert users, "need at least one user"
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={
            "title": "Patch persistence",
            "status_id": statuses[0]["id"],
            "assignee_ids": [users[0]["id"]],
        },
    )
    assert created.status_code == 200, created.text
    tid = created.json()["task"]["id"]
    patched = await client.patch(
        f"/api/v1/tasks/{tid}",
        headers=headers,
        json={
            "due_date": "2031-03-01T10:00:00Z",
            "assignee_ids": [users[0]["id"]],
            "title": "Patch persistence saved",
        },
    )
    assert patched.status_code == 200, patched.text
    body = patched.json()["task"]
    assert body["title"] == "Patch persistence saved"
    assert body["due_date"] is not None
    assert any(a["id"] == users[0]["id"] for a in body["assignees"])
    fetched = await client.get(f"/api/v1/tasks/{tid}")
    assert fetched.status_code == 200
    fresh = fetched.json()["task"]
    assert fresh["title"] == "Patch persistence saved"
    assert fresh["due_date"] is not None
    assert any(a["id"] == users[0]["id"] for a in fresh["assignees"])


@pytest.mark.asyncio
async def test_list_comment_count(client: AsyncClient):
    headers = await _login_admin(client)
    uid = await current_user_id(client)
    statuses = (await client.get("/api/v1/settings/statuses")).json()["items"]
    status_id = statuses[0]["id"]
    created = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "With comment count", "status_id": status_id, "assignee_ids": [uid]},
    )
    tid = created.json()["task"]["id"]
    c = await client.post(
        f"/api/v1/tasks/{tid}/comments",
        headers=headers,
        json={"body": "hello count"},
    )
    assert c.status_code == 200, c.text
    listed = await client.get("/api/v1/tasks?page_size=200")
    assert listed.status_code == 200
    item = next(t for t in listed.json()["items"] if t["id"] == tid)
    assert item["comment_count"] >= 1
