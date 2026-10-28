import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_not_found(client: AsyncClient):
    r = await client.post("/api/v1/auth/register", json={"email": "a@b.com", "password": "x"})
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_login_admin(client: AsyncClient):
    r = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["user"]["role"] == "admin"
    assert "access_token" in r.cookies or "access_token" in [c.split("=")[0] for c in r.headers.get_list("set-cookie")]


@pytest.mark.asyncio
async def test_member_cannot_admin(client: AsyncClient):
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    csrf = client.cookies.get("csrf_token")
    headers = {"X-CSRF-Token": csrf} if csrf else {}
    create = await client.post(
        "/api/v1/admin/users",
        headers=headers,
        json={
            "name": "Member",
            "email": "mem@test.com",
            "role": "member",
            "password": "Member123!Test",
            "must_change_password": True,
        },
    )
    assert create.status_code == 200
    await client.post("/api/v1/auth/logout", headers=headers)
    mlogin = await client.post(
        "/api/v1/auth/login",
        json={"email": "mem@test.com", "password": "Member123!Test"},
    )
    assert mlogin.status_code == 200
    csrf2 = client.cookies.get("csrf_token")
    r = await client.get("/api/v1/admin/users", headers={"X-CSRF-Token": csrf2 or ""})
    assert r.status_code == 403
