"""Self-service account deletion — store compliance."""

import uuid

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


async def _client():
    async def override_get_db():
        async with TestSession() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _join(project_id: str, owner: AsyncClient, *, name: str, email: str) -> None:
    inv = await owner.post(f"/api/v1/projects/{project_id}/invites", json={"email": email})
    assert inv.status_code == 200, inv.text
    async with await _client() as member:
        await register_verified(member, name=name, email=email, password="SecurePass123!")
        mine = await member.get("/api/v1/invites/mine")
        invite_id = mine.json()["items"][0]["id"]
        accepted = await member.post(f"/api/v1/invites/{invite_id}/accept")
        assert accepted.status_code == 200, accepted.text


async def _create_project(client: AsyncClient, name: str) -> str:
    created = await client.post(
        "/api/v1/projects",
        json={"name": name, "description": "", "color": "#315F72", "icon": "folder",
              "member_ids": []},
    )
    assert created.status_code == 200, created.text
    return created.json()["project"]["id"]


@pytest.mark.asyncio
async def test_sole_admin_transfers_rights_to_earliest_real_member(client: AsyncClient):
    await register_verified(
        client, name="Owner", email="owner-delete@test.com", password="SecurePass123!"
    )
    project_id = await _create_project(client, "Команда")
    await _join(project_id, client, name="Первый Участник", email="first-delete@test.com")
    await _join(project_id, client, name="Второй Участник", email="second-delete@test.com")

    owner = await client.post(
        "/api/v1/auth/login",
        json={"email": "owner-delete@test.com", "password": "SecurePass123!"},
    )
    assert owner.status_code == 200, owner.text

    preview = await client.get("/api/v1/users/me/delete-preview")
    assert preview.status_code == 200, preview.text
    body = preview.json()
    assert body["can_delete"] is True
    [plan] = body["projects"]
    assert plan["action"] == "transfer"
    assert plan["new_admin"]["name"] == "Первый Участник"
    assert "перейдут к Первый Участник" in plan["summary"]

    deleted = await client.delete("/api/v1/users/me")
    assert deleted.status_code == 200, deleted.text

    async with await _client() as heir:
        login = await heir.post(
            "/api/v1/auth/login",
            json={"email": "first-delete@test.com", "password": "SecurePass123!"},
        )
        assert login.status_code == 200
        from sqlalchemy import select

        from app.models.project import ProjectMember
        from app.models.user import User

        async with TestSession() as db:
            rows = (
                await db.execute(
                    select(User.email, ProjectMember.role)
                    .join(ProjectMember, ProjectMember.user_id == User.id)
                    .where(ProjectMember.project_id == uuid.UUID(project_id))
                )
            ).all()
        roles = {email: role.value for email, role in rows}
        assert roles == {"first-delete@test.com": "admin", "second-delete@test.com": "member"}

        notes = await heir.get("/api/v1/notifications")
        assert notes.status_code == 200
        raw_n = notes.json()
        n_items = raw_n if isinstance(raw_n, list) else raw_n.get("items", [])
        assert any(
            n["kind"] == "project_admin_granted" and "«Команда»" in n["title"] for n in n_items
        )


@pytest.mark.asyncio
async def test_sole_admin_with_only_demo_members_deletes_project(client: AsyncClient):
    from sqlalchemy import select

    from app.models.project import Project, ProjectMember, ProjectMemberRole
    from app.models.user import User
    from app.services.account_service import delete_own_account

    await register_verified(client, name="Solo", email="demoonly@test.com")
    project_id = await _create_project(client, "Только демо")

    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == "demoonly@test.com"))
        demo = User(email="demo.staff.x@example.com", name="Демо Сотрудник",
                    password_hash=None, is_demo=True)
        db.add(demo)
        await db.flush()
        import uuid as _uuid
        db.add(ProjectMember(project_id=_uuid.UUID(project_id), user_id=demo.id,
                             role=ProjectMemberRole.member))
        await db.commit()

    preview = await client.get("/api/v1/users/me/delete-preview")
    [plan] = preview.json()["projects"]
    assert plan["action"] == "delete"
    assert plan["summary"] == "Проект «Только демо» будет удалён."

    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == "demoonly@test.com"))
        await delete_own_account(db, me)
        await db.commit()
    async with TestSession() as db:
        assert await db.get(Project, _uuid.UUID(project_id)) is None
        left = (await db.scalars(
            select(ProjectMember).where(ProjectMember.project_id == _uuid.UUID(project_id))
        )).all()
        assert left == []


@pytest.mark.asyncio
async def test_last_super_admin_still_protected(admin_client: AsyncClient):
    preview = await admin_client.get("/api/v1/users/me/delete-preview")
    assert preview.status_code == 200
    assert preview.json()["can_delete"] is False
    assert preview.json()["blocked"]["code"] == "last_super_admin"
    blocked = await admin_client.delete("/api/v1/users/me")
    assert blocked.status_code == 409
    assert blocked.json()["detail"]["error"]["code"] == "last_super_admin"


@pytest.mark.asyncio
async def test_review_account_can_be_deleted_after_seed(client: AsyncClient):
    from sqlalchemy import func, select

    from app.models.project import Project
    from app.services.review_account_seed import REVIEW_PROJECTS, seed_review_account

    email, password = "reviewer-del@example.com", "Review-Pass-123!"
    async with TestSession() as db:
        report = await seed_review_account(db, email=email, password=password)
    ids = [p["id"] for p in report["projects"]]
    from app.models.task import Attachment
    from app.services.attachment_service import attachment_path

    async with TestSession() as db:
        files = [attachment_path(a) for a in (await db.scalars(select(Attachment))).all()]
    assert files and all(f.exists() for f in files)

    login = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert login.status_code == 200, login.text
    preview = await client.get("/api/v1/users/me/delete-preview")
    body = preview.json()
    assert body["can_delete"] is True
    assert len(body["projects"]) == len(REVIEW_PROJECTS)
    assert all(p["action"] == "delete" for p in body["projects"])

    deleted = await client.delete("/api/v1/users/me")
    assert deleted.status_code == 200, deleted.text
    import uuid as _uuid
    async with TestSession() as db:
        left = await db.scalar(
            select(func.count()).select_from(Project)
            .where(Project.id.in_([_uuid.UUID(i) for i in ids]))
        )
        assert left == 0
    assert not any(f.exists() for f in files), "файлы удалённых проектов остались на диске"


@pytest.mark.asyncio
async def test_files_survive_rollback_and_go_after_commit(client: AsyncClient):
    """Файлы вложений удаляются только после успешного commit."""
    from sqlalchemy import select

    from app.models.project import Project
    from app.models.task import Attachment, Task
    from app.models.user import User
    from app.services import project_service
    from app.services.account_service import delete_own_account
    from app.services.attachment_service import attachment_path
    from app.services.review_account_seed import seed_review_account

    email, password = "reviewer-rollback@example.com", "Review-Pass-123!"
    async with TestSession() as db:
        report = await seed_review_account(db, email=email, password=password)
    async with TestSession() as db:
        files = [attachment_path(a) for a in (await db.scalars(select(Attachment))).all()]
    assert files and all(f.exists() for f in files)

    # Удаление аккаунта: сервис только возвращает папки; откат — файлы на месте.
    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == email))
        result = await delete_own_account(db, me)
        assert result["file_dirs"]
        await db.rollback()
    assert all(f.exists() for f in files)

    # Удаление проекта: то же самое при откате.
    project_id = uuid.UUID(report["projects"][0]["id"])
    async with TestSession() as db:
        me = await db.scalar(select(User).where(User.email == email))
        dirs = await project_service.delete_project(db, project_id=project_id, actor=me)
        assert dirs
        await db.rollback()  # роутер удаляет папки только после commit
    assert all(f.exists() for f in files)
    async with TestSession() as db:
        assert await db.get(Project, project_id) is not None

    # Через API (commit успешен) — файлы проекта удаляются.
    login = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert login.status_code == 200, login.text
    async with TestSession() as db:
        project_files = [
            attachment_path(a)
            for a in (await db.scalars(
                select(Attachment).join(Attachment.task).where(
                    Task.project_id == project_id
                )
            )).all()
        ]
    assert project_files
    r = await client.delete(f"/api/v1/projects/{project_id}")
    assert r.status_code == 200, r.text
    assert not any(f.exists() for f in project_files)
