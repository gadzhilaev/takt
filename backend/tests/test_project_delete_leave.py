import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from tests.conftest import TestSession, register_verified


@pytest.mark.asyncio
async def test_owner_deletes_project(admin_client: AsyncClient):
    created = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "To Delete",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert created.status_code == 200, created.text
    pid = created.json()["project"]["id"]

    deleted = await admin_client.delete(f"/api/v1/projects/{pid}")
    assert deleted.status_code == 200, deleted.text

    gone = await admin_client.get(f"/api/v1/projects/{pid}")
    assert gone.status_code in (403, 404)


@pytest.mark.asyncio
async def test_member_leaves_project_immediately(admin_client: AsyncClient):
    created = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "Leave Now",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert created.status_code == 200, created.text
    pid = created.json()["project"]["id"]

    inv = await admin_client.post(
        f"/api/v1/projects/{pid}/invites",
        json={"email": "leavenow@example.com"},
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
        await register_verified(member, name="Участник", email="leavenow@example.com")
        mine = await member.get("/api/v1/invites/mine")
        invite_id = mine.json()["items"][0]["id"]
        assert (await member.post(f"/api/v1/invites/{invite_id}/accept")).status_code == 200

        left = await member.post(f"/api/v1/projects/{pid}/leave")
        assert left.status_code == 200, left.text

        listed = await member.get("/api/v1/projects")
        assert all(p["id"] != pid for p in listed.json()["items"])
