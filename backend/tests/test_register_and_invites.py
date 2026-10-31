import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from tests.conftest import TestSession, register_verified


@pytest.mark.asyncio
async def test_register_login_and_create_project(client: AsyncClient):
    email = "newbie@example.com"
    reg = await register_verified(client, name="Новичок", email=email)
    user = reg["user"]
    assert user["email"] == email
    assert user["role"] == "member"
    assert user["must_change_password"] is False

    me = await client.get("/api/v1/auth/me")
    assert me.status_code == 200

    project = await client.post(
        "/api/v1/projects",
        json={
            "name": "Мой проект",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert project.status_code == 200, project.text
    pid = project.json()["project"]["id"]
    members = project.json()["project"]["members"]
    assert len(members) == 1
    assert members[0]["role"] == "admin"

    statuses = await client.get(f"/api/v1/settings/statuses?project_id={pid}")
    assert statuses.status_code == 200
    names = [s["name"] for s in statuses.json()["items"]]
    assert names == ["К выполнению", "В работе", "На проверке", "Готово"]


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient):
    await register_verified(client, name="A", email="dup@example.com")
    again = await client.post(
        "/api/v1/auth/register/send-code",
        json={
            "name": "A",
            "email": "dup@example.com",
            "password": "SecurePass123!",
            "password_confirm": "SecurePass123!",
        },
    )
    assert again.status_code == 400


@pytest.mark.asyncio
async def test_invite_accept_flow(admin_client: AsyncClient):
    project = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "Invite Proj",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert project.status_code == 200, project.text
    pid = project.json()["project"]["id"]

    inv = await admin_client.post(
        f"/api/v1/projects/{pid}/invites",
        json={"email": "invitee@example.com"},
    )
    assert inv.status_code == 200, inv.text
    assert inv.json()["email_delivery"] == "in_app_only"

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
    async with AsyncClient(transport=transport, base_url="http://test") as invitee:
        reg = await register_verified(invitee, name="Invitee", email="invitee@example.com")
        assert reg["user"]["email"] == "invitee@example.com"
        mine = await invitee.get("/api/v1/invites/mine")
        assert mine.status_code == 200
        items = mine.json()["items"]
        assert len(items) >= 1
        invite_id = items[0]["id"]
        acc = await invitee.post(f"/api/v1/invites/{invite_id}/accept")
        assert acc.status_code == 200, acc.text
        projects = await invitee.get("/api/v1/projects")
        ids = [p["id"] for p in projects.json()["items"]]
        assert pid in ids


@pytest.mark.asyncio
async def test_open_invite_link_flow(admin_client: AsyncClient):
    project = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "Link Proj",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert project.status_code == 200, project.text
    pid = project.json()["project"]["id"]

    inv = await admin_client.post(f"/api/v1/projects/{pid}/invites", json={})
    assert inv.status_code == 200, inv.text
    token = inv.json()["invite"]["token"]
    assert token
    assert inv.json()["invite"]["email"] is None

    # Reuse same open invite
    again = await admin_client.post(f"/api/v1/projects/{pid}/invites", json={})
    assert again.status_code == 200
    assert again.json()["invite"]["token"] == token

    public = await admin_client.get(f"/api/v1/invites/token/{token}")
    assert public.status_code == 200
    assert public.json()["requires_email_match"] is False

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
    async with AsyncClient(transport=transport, base_url="http://test") as joiner:
        await register_verified(joiner, name="Joiner", email="joiner@example.com")
        acc = await joiner.post(f"/api/v1/invites/token/{token}/accept")
        assert acc.status_code == 200, acc.text
        projects = await joiner.get("/api/v1/projects")
        ids = [p["id"] for p in projects.json()["items"]]
        assert pid in ids
