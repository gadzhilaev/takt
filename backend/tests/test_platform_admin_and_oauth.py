"""Platform admin ACL + OAuth provider policy (no live provider credentials)."""

import pytest
from httpx import AsyncClient

from tests.conftest import register_verified


@pytest.mark.asyncio
async def test_member_cannot_access_platform_admin(client: AsyncClient):
    await register_verified(client, name="Member", email="plat-member@example.com")
    r = await client.get("/api/v1/platform/dashboard")
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_project_admin_is_not_platform_admin(client: AsyncClient, admin_client: AsyncClient):
    """Project membership admin must not unlock /platform APIs."""
    await register_verified(client, name="ProjAdmin", email="proj-admin@example.com")
    # Create a project — creator is project admin, still not platform admin.
    created = await client.post("/api/v1/projects", json={"name": "ACL check"})
    assert created.status_code in (200, 201)
    r = await client.get("/api/v1/platform/dashboard")
    assert r.status_code == 403
    # Legacy team admin API also forbidden for pure members
    r2 = await client.get("/api/v1/admin/users")
    assert r2.status_code == 403


@pytest.mark.asyncio
async def test_platform_admin_dashboard(admin_client: AsyncClient):
    r = await admin_client.get("/api/v1/platform/dashboard")
    assert r.status_code == 200
    body = r.json()
    assert "users_total" in body
    assert "dau" in body
    assert body["metrics_note"]


@pytest.mark.asyncio
async def test_platform_users_pagination(admin_client: AsyncClient):
    r = await admin_client.get("/api/v1/platform/users?page=1&page_size=10")
    assert r.status_code == 200
    body = r.json()
    assert "items" in body and "total" in body


@pytest.mark.asyncio
async def test_block_unblock_and_audit(client: AsyncClient):
    await register_verified(client, name="BlockMe", email="block-me@example.com")
    # Same AsyncClient: re-login as platform admin after member registration.
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    assert login.status_code == 200
    users = await client.get("/api/v1/platform/users?q=block-me@example.com")
    assert users.status_code == 200, users.text
    items = users.json()["items"]
    assert items
    uid = items[0]["id"]
    blocked = await client.post(
        f"/api/v1/platform/users/{uid}/block",
        json={"reason": "тест ограничения"},
    )
    assert blocked.status_code == 200, blocked.text
    unblocked = await client.post(f"/api/v1/platform/users/{uid}/unblock")
    assert unblocked.status_code == 200
    audit = await client.get("/api/v1/platform/security/audit")
    assert audit.status_code == 200
    actions = [a["action"] for a in audit.json()["items"]]
    assert "user_blocked" in actions
    assert "user_unblocked" in actions


@pytest.mark.asyncio
async def test_platform_user_update_and_delete(client: AsyncClient):
    await register_verified(client, name="EditMe", email="edit-me@example.com")
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    assert login.status_code == 200
    users = await client.get("/api/v1/platform/users?q=edit-me@example.com")
    uid = users.json()["items"][0]["id"]

    patched = await client.patch(
        f"/api/v1/platform/users/{uid}",
        json={
            "name": "Отредактирован",
            "email": "edited-me@example.com",
            "password": "NewPass123!",
            "must_change_password": True,
        },
    )
    assert patched.status_code == 200, patched.text
    body = patched.json()["user"]
    assert body["name"] == "Отредактирован"
    assert body["email"] == "edited-me@example.com"
    assert body["must_change_password"] is True
    assert body["has_password"] is True

    deleted = await client.delete(f"/api/v1/platform/users/{uid}")
    assert deleted.status_code == 200, deleted.text
    gone = await client.get(f"/api/v1/platform/users/{uid}")
    assert gone.status_code == 404
    audit = await client.get("/api/v1/platform/security/audit")
    actions = [a["action"] for a in audit.json()["items"]]
    assert "user_updated" in actions
    assert "user_deleted" in actions


@pytest.mark.asyncio
async def test_oauth_providers_public_and_disabled_by_default(client: AsyncClient):
    r = await client.get("/api/v1/auth/oauth/providers")
    assert r.status_code == 200
    body = r.json()
    assert body["email_password"] is True
    assert body["providers"]["apple"]["enabled"] is False
    assert body["providers"]["vk"]["enabled"] is False
    assert body["providers"]["yandex"]["enabled"] is False


@pytest.mark.asyncio
async def test_oauth_start_disabled_provider(client: AsyncClient):
    r = await client.get("/api/v1/auth/oauth/vk/start")
    assert r.status_code == 400
    assert r.json()["detail"]["error"]["code"] == "provider_disabled"


@pytest.mark.asyncio
async def test_projects_metadata_only(admin_client: AsyncClient):
    r = await admin_client.get("/api/v1/platform/projects")
    assert r.status_code == 200
    for item in r.json()["items"]:
        assert item.get("content_access") == "metadata_only"
        assert "tasks" not in item


@pytest.mark.asyncio
async def test_project_detail_members(admin_client: AsyncClient):
    created = await admin_client.post("/api/v1/projects", json={"name": "Admin members view"})
    assert created.status_code in (200, 201), created.text
    pid = created.json()["project"]["id"]
    detail = await admin_client.get(f"/api/v1/platform/projects/{pid}")
    assert detail.status_code == 200, detail.text
    body = detail.json()
    assert body["name"] == "Admin members view"
    assert body["content_access"] == "metadata_only"
    assert isinstance(body["members"], list)
    assert len(body["members"]) >= 1
    assert "email" in body["members"][0]
