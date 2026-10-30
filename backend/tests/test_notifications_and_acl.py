import pytest
from httpx import AsyncClient

from tests.conftest import register_verified


async def _login(client: AsyncClient, email: str, password: str) -> None:
    r = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text


async def _register(client: AsyncClient, name: str, email: str, password: str = "SecurePass123!") -> dict:
    data = await register_verified(client, name=name, email=email, password=password)
    return data["user"]


async def _accept_all_invites(client: AsyncClient) -> None:
    invites = (await client.get("/api/v1/invites/mine")).json()["items"]
    for inv in invites:
        await client.post(f"/api/v1/invites/{inv['id']}/accept")


@pytest.mark.asyncio
async def test_only_author_can_delete_task(client: AsyncClient):
    await _register(client, "Author User", "author-del@example.com")
    await client.post("/api/v1/auth/logout")
    await _register(client, "Other User", "other-del@example.com")
    await client.post("/api/v1/auth/logout")

    await _login(client, "admin@test.com", "Admin123!Test")
    proj = await client.post(
        "/api/v1/projects",
        json={"name": "ACL Project", "description": None, "color": "#315F72"},
    )
    assert proj.status_code == 200, proj.text
    pid = proj.json()["project"]["id"]
    await client.post(f"/api/v1/projects/{pid}/invites", json={"email": "author-del@example.com"})
    await client.post(f"/api/v1/projects/{pid}/invites", json={"email": "other-del@example.com"})

    await _login(client, "author-del@example.com", "SecurePass123!")
    await _accept_all_invites(client)
    statuses = (await client.get(f"/api/v1/settings/statuses?project_id={pid}")).json()["items"]
    created = await client.post(
        "/api/v1/tasks",
        json={"title": "Author task", "status_id": statuses[0]["id"], "project_id": pid},
    )
    task_id = created.json()["task"]["id"]

    await _login(client, "other-del@example.com", "SecurePass123!")
    await _accept_all_invites(client)
    forbidden = await client.delete(f"/api/v1/tasks/{task_id}")
    assert forbidden.status_code == 403

    await _login(client, "author-del@example.com", "SecurePass123!")
    ok = await client.delete(f"/api/v1/tasks/{task_id}")
    assert ok.status_code == 200


@pytest.mark.asyncio
async def test_assignment_and_completion_notifications(client: AsyncClient):
    await _register(client, "Велиева Сабина", "sabina@example.com")
    await client.post("/api/v1/auth/logout")
    await _register(client, "Кадачиев Алибек", "alibek@example.com")
    await client.post("/api/v1/auth/logout")

    await _login(client, "admin@test.com", "Admin123!Test")
    proj = await client.post(
        "/api/v1/projects",
        json={"name": "Notify Project", "description": None, "color": "#315F72"},
    )
    pid = proj.json()["project"]["id"]
    for email in ("sabina@example.com", "alibek@example.com"):
        await client.post(f"/api/v1/projects/{pid}/invites", json={"email": email})

    await _login(client, "alibek@example.com", "SecurePass123!")
    await _accept_all_invites(client)
    await _login(client, "sabina@example.com", "SecurePass123!")
    await _accept_all_invites(client)
    statuses = (await client.get(f"/api/v1/settings/statuses?project_id={pid}")).json()["items"]
    open_col = next(s for s in statuses if not s["is_done"])
    done_col = next(s for s in statuses if s["is_done"])
    users = (await client.get("/api/v1/users")).json()["items"]
    alibek = next(u for u in users if u["email"] == "alibek@example.com")

    created = await client.post(
        "/api/v1/tasks",
        json={
            "title": "Исправить 1С",
            "status_id": open_col["id"],
            "project_id": pid,
            "assignee_ids": [alibek["id"]],
        },
    )
    assert created.status_code == 200, created.text
    task_id = created.json()["task"]["id"]

    await _login(client, "alibek@example.com", "SecurePass123!")
    notes = (await client.get("/api/v1/notifications")).json()["items"]
    assign = [n for n in notes if n["kind"] == "task_assigned"]
    assert assign
    assert "Вам" in assign[0]["title"]
    assert "Исправить 1С" in assign[0]["title"]

    moved = await client.post(
        f"/api/v1/tasks/{task_id}/move",
        json={"status_id": done_col["id"], "position": 100},
    )
    assert moved.status_code == 200

    await _login(client, "sabina@example.com", "SecurePass123!")
    notes2 = (await client.get("/api/v1/notifications")).json()["items"]
    done_notes = [n for n in notes2 if n["kind"] == "task_completed"]
    assert done_notes
    assert "Кадачиев Алибек" in done_notes[0]["title"]
    assert "завершил" in done_notes[0]["title"]

    await client.post(
        f"/api/v1/tasks/{task_id}/move",
        json={"status_id": done_col["id"], "position": 50},
    )
    notes3 = (await client.get("/api/v1/notifications")).json()["items"]
    assert len([n for n in notes3 if n["kind"] == "task_completed"]) == len(done_notes)


@pytest.mark.asyncio
async def test_delete_column_moves_tasks(client: AsyncClient):
    await _login(client, "admin@test.com", "Admin123!Test")
    proj = await client.post(
        "/api/v1/projects",
        json={"name": "Cols", "description": None, "color": "#315F72"},
    )
    pid = proj.json()["project"]["id"]
    statuses = (await client.get(f"/api/v1/settings/statuses?project_id={pid}")).json()["items"]
    assert len(statuses) == 4
    src = statuses[1]
    dst = statuses[0]
    created = await client.post(
        "/api/v1/tasks",
        json={"title": "Move me", "status_id": src["id"], "project_id": pid},
    )
    task_id = created.json()["task"]["id"]
    bad = await client.delete(f"/api/v1/settings/statuses/{src['id']}")
    assert bad.status_code == 400
    ok = await client.delete(f"/api/v1/settings/statuses/{src['id']}?move_to_status_id={dst['id']}")
    assert ok.status_code == 200, ok.text
    task = (await client.get(f"/api/v1/tasks/{task_id}")).json()["task"]
    assert task["status_id"] == dst["id"]


@pytest.mark.asyncio
async def test_task_endpoints_require_project_membership(client: AsyncClient):
    """Пользователь без членства не читает и не меняет чужие задачи (IDOR)."""
    await _register(client, "Owner ACL", "owner-acl@example.com")
    await client.post("/api/v1/auth/logout")
    await _register(client, "Stranger ACL", "stranger-acl@example.com")
    await client.post("/api/v1/auth/logout")

    await _login(client, "owner-acl@example.com", "SecurePass123!")
    proj = await client.post(
        "/api/v1/projects",
        json={"name": "Private ACL", "description": None, "color": "#315F72"},
    )
    assert proj.status_code == 200, proj.text
    pid = proj.json()["project"]["id"]
    statuses = (await client.get(f"/api/v1/settings/statuses?project_id={pid}")).json()["items"]
    created = await client.post(
        "/api/v1/tasks",
        json={"title": "Secret", "status_id": statuses[0]["id"], "project_id": pid},
    )
    task_id = created.json()["task"]["id"]

    await _login(client, "stranger-acl@example.com", "SecurePass123!")
    assert (await client.get(f"/api/v1/tasks/{task_id}")).status_code == 403
    assert (await client.get(f"/api/v1/tasks/{task_id}/comments")).status_code == 403
    listed = await client.get("/api/v1/tasks")
    assert listed.status_code == 200
    assert all(t["id"] != task_id for t in listed.json()["items"])
    assert (
        await client.patch(f"/api/v1/tasks/{task_id}", json={"title": "Hacked"})
    ).status_code == 403


@pytest.mark.asyncio
async def test_ru_assignment_copy():
    from app.services.ru_names import format_assignment_title, format_completed_title

    title = format_assignment_title(
        actor_name="Велиева Сабина",
        recipient_id="1",
        assignees=[("1", "Кадачиев Алибек"), ("2", "Рагимов Рахман")],
        task_title="Проверить",
    )
    assert "Вам" in title
    assert "назначила" in title
    assert "Рагимов Рахман" in title
    assert "Рагимову" not in title
    assert format_completed_title(actor_name="Кадачиев Алибек", task_title="X").startswith(
        "Кадачиев Алибек завершил"
    )
