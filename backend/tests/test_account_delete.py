"""Self-service account deletion — store compliance."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from tests.conftest import TestSession, register_verified


@pytest.mark.asyncio
async def test_delete_own_account_sole_project(client: AsyncClient):
    await register_verified(
        client, name="Solo User", email="solo-delete@test.com", password="SecurePass123!"
    )
    created = await client.post(
        "/api/v1/projects",
        json={
            "name": "Личный проект",
            "description": "only me",
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert created.status_code == 200, created.text
    project_id = created.json()["project"]["id"]

    deleted = await client.delete("/api/v1/users/me")
    assert deleted.status_code == 200, deleted.text
    assert deleted.json()["ok"] is True

    me = await client.get("/api/v1/auth/me")
    assert me.status_code == 401

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "solo-delete@test.com", "password": "SecurePass123!"},
    )
    assert login.status_code in (401, 400, 403)

    admin = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    assert admin.status_code == 200
    projects = await client.get("/api/v1/projects")
    assert projects.status_code == 200
    ids = [p["id"] for p in projects.json()["items"]]
    assert project_id not in ids


@pytest.mark.asyncio
async def test_delete_blocked_when_sole_admin_with_members(client: AsyncClient):
    await register_verified(
        client, name="Owner", email="owner-delete@test.com", password="SecurePass123!"
    )
    created = await client.post(
        "/api/v1/projects",
        json={
            "name": "Команда",
            "description": "shared",
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert created.status_code == 200, created.text
    project_id = created.json()["project"]["id"]

    inv = await client.post(
        f"/api/v1/projects/{project_id}/invites",
        json={"email": "member-delete@test.com"},
    )
    assert inv.status_code == 200, inv.text

    async def override_get_db():
        async with TestSession() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as member:
        await register_verified(
            member, name="Member", email="member-delete@test.com", password="SecurePass123!"
        )
        mine = await member.get("/api/v1/invites/mine")
        assert mine.status_code == 200
        invite_id = mine.json()["items"][0]["id"]
        accepted = await member.post(f"/api/v1/invites/{invite_id}/accept")
        assert accepted.status_code == 200, accepted.text

    owner = await client.post(
        "/api/v1/auth/login",
        json={"email": "owner-delete@test.com", "password": "SecurePass123!"},
    )
    assert owner.status_code == 200, owner.text

    blocked = await client.delete("/api/v1/users/me")
    assert blocked.status_code == 409, blocked.text
    assert blocked.json()["detail"]["error"]["code"] == "sole_admin"
