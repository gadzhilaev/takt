import pytest
from httpx import AsyncClient

from tests.conftest import register_verified


@pytest.mark.asyncio
async def test_workspace_lists_only_membership_projects(client: AsyncClient):
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    # Create a regular project as admin (membership via create)
    proj = await client.post(
        "/api/v1/projects",
        json={"name": "Work Board", "description": None, "color": "#315F72"},
    )
    assert proj.status_code == 200
    work_id = proj.json()["project"]["id"]

    # Ordinary user creates own non-demo project — admin must not see it in workspace.
    await client.post("/api/v1/auth/logout")
    reg = await register_verified(
        client, name="Участник", email="member-iso@example.com"
    )
    assert reg["user"]["email"] == "member-iso@example.com"
    foreign = await client.post(
        "/api/v1/projects",
        json={
            "name": "Чужой проект",
            "description": None,
            "color": "#315F72",
        },
    )
    assert foreign.status_code == 200, foreign.text
    foreign_id = foreign.json()["project"]["id"]
    assert foreign.json()["project"]["is_demo"] is False

    # Same user creates demo/[E2E] project
    e2e = await client.post(
        "/api/v1/projects",
        json={
            "name": "[E2E] Isolation",
            "description": "Isolated Playwright project [demo-workspace]",
            "color": "#315F72",
        },
    )
    assert e2e.status_code == 200, e2e.text
    e2e_id = e2e.json()["project"]["id"]
    assert e2e.json()["project"]["is_demo"] is True

    member_list = (await client.get("/api/v1/projects")).json()["items"]
    assert any(p["id"] == foreign_id for p in member_list)
    assert any(p["id"] == e2e_id for p in member_list)

    await client.post("/api/v1/auth/logout")
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    admin_list = (await client.get("/api/v1/projects")).json()["items"]
    assert any(p["id"] == work_id for p in admin_list)
    assert all(p["id"] != foreign_id for p in admin_list)
    assert all(p["id"] != e2e_id for p in admin_list)

    # Direct access without membership must fail for both
    assert (await client.get(f"/api/v1/projects/{e2e_id}")).status_code == 403
    assert (await client.get(f"/api/v1/projects/{foreign_id}")).status_code == 403
