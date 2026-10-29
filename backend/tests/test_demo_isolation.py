import pytest
from httpx import AsyncClient

from tests.conftest import register_verified


@pytest.mark.asyncio
async def test_demo_projects_hidden_from_admin_without_membership(client: AsyncClient):
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    # Create a regular project as admin
    proj = await client.post(
        "/api/v1/projects",
        json={"name": "Work Board", "description": None, "color": "#315F72"},
    )
    assert proj.status_code == 200

    # Register demo-like user and create [E2E] project (auto is_demo)
    await client.post("/api/v1/auth/logout")
    reg = await register_verified(
        client, name="Демо пользователь", email="demo-iso@example.com"
    )
    assert reg["user"]["email"] == "demo-iso@example.com"
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

    demo_list = (await client.get("/api/v1/projects")).json()["items"]
    assert any(p["id"] == e2e_id for p in demo_list)

    await client.post("/api/v1/auth/logout")
    await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    admin_list = (await client.get("/api/v1/projects")).json()["items"]
    assert all(p["id"] != e2e_id for p in admin_list)
    assert any(p["name"] == "Work Board" for p in admin_list)

    # Direct access without membership must fail for demo project
    denied = await client.get(f"/api/v1/projects/{e2e_id}")
    assert denied.status_code == 403
