import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.main import app
from tests.conftest import TestSession, register_verified


@pytest.mark.asyncio
async def test_leave_request_and_owner_remove(admin_client: AsyncClient):
    project = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "Leave Proj",
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
        json={"email": "leaver@example.com"},
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
        reg = await register_verified(member, name="Участник", email="leaver@example.com")
        member_id = reg["user"]["id"]
        assert reg.get("joined_project_id") == pid

        leave = await member.post(f"/api/v1/projects/{pid}/leave-requests")
        assert leave.status_code == 200, leave.text
        req_id = leave.json()["request"]["id"]

        listed = await admin_client.get(f"/api/v1/projects/{pid}/leave-requests")
        assert listed.status_code == 200
        assert any(i["id"] == req_id for i in listed.json()["items"])

        reject = await admin_client.post(
            f"/api/v1/projects/{pid}/leave-requests/{req_id}/reject"
        )
        assert reject.status_code == 200, reject.text

        leave2 = await member.post(f"/api/v1/projects/{pid}/leave-requests")
        assert leave2.status_code == 200, leave2.text
        req2 = leave2.json()["request"]["id"]
        approve = await admin_client.post(
            f"/api/v1/projects/{pid}/leave-requests/{req2}/approve"
        )
        assert approve.status_code == 200, approve.text

        projects = await member.get("/api/v1/projects")
        assert all(p["id"] != pid for p in projects.json()["items"])

        # Re-join then owner removes directly
        inv2 = await admin_client.post(
            f"/api/v1/projects/{pid}/invites",
            json={"email": "leaver@example.com"},
        )
        assert inv2.status_code == 200, inv2.text
        mine2 = await member.get("/api/v1/invites/mine")
        invite2 = mine2.json()["items"][0]["id"]
        assert (await member.post(f"/api/v1/invites/{invite2}/accept")).status_code == 200

        removed = await admin_client.delete(f"/api/v1/projects/{pid}/members/{member_id}")
        assert removed.status_code == 200, removed.text
        assert all(m["user_id"] != member_id for m in removed.json()["project"]["members"])
