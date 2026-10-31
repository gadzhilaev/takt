"""Global Takt platform administration API — not project admin."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    require_platform_admin,
    require_platform_moderator,
    require_super_admin,
    verify_csrf,
)
from app.core.config import get_settings
from app.db.session import get_db
from app.models.platform import ModerationReport, ModerationReportStatus
from app.models.task import AdminAuditLog
from app.models.user import PlatformRole, User
from app.services import platform_admin_service as pas
from app.services.oauth_service import provider_availability

router = APIRouter(
    prefix="/platform",
    tags=["platform-admin"],
    dependencies=[Depends(verify_csrf)],
)


def _err(e: pas.PlatformError) -> HTTPException:
    return HTTPException(
        status_code=e.status_code,
        detail={"error": {"code": e.code, "message": e.message}},
    )


@router.get("/dashboard")
async def dashboard(
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    return await pas.dashboard_stats(db)


@router.get("/users")
async def users(
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str | None = None,
    status: str | None = None,
    registered_from: datetime | None = None,
    registered_to: datetime | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort: str | None = Query(None, pattern="^(name|email|role|created_at|last_login_at)$"),
    sort_dir: str | None = Query(None, pattern="^(asc|desc)$"),
):
    return await pas.list_users(
        db,
        q=q,
        status=status,
        registered_from=registered_from,
        registered_to=registered_to,
        page=page,
        page_size=page_size,
        sort=sort,
        sort_dir=sort_dir,
    )


@router.get("/users/{user_id}")
async def user_card(
    user_id: uuid.UUID,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        return await pas.user_detail(db, user_id)
    except pas.PlatformError as e:
        raise _err(e)


class BlockBody(BaseModel):
    reason: str = Field(min_length=3, max_length=2000)
    until: datetime | None = None


@router.post("/users/{user_id}/block")
async def block_user(
    user_id: uuid.UUID,
    body: BlockBody,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        user = await pas.block_user(db, admin, user_id, reason=body.reason, until=body.until)
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return {"user": pas._user_row(user)}


@router.post("/users/{user_id}/unblock")
async def unblock_user(
    user_id: uuid.UUID,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        user = await pas.unblock_user(db, admin, user_id)
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return {"user": pas._user_row(user)}


class RoleBody(BaseModel):
    platform_role: PlatformRole


class UserUpdateBody(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    email: str | None = Field(default=None, min_length=3, max_length=320)
    is_active: bool | None = None
    must_change_password: bool | None = None
    password: str | None = Field(default=None, min_length=8, max_length=128)
    platform_role: PlatformRole | None = None


@router.patch("/users/{user_id}")
async def update_user(
    user_id: uuid.UUID,
    body: UserUpdateBody,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        user = await pas.update_user(
            db,
            admin,
            user_id,
            name=body.name,
            email=body.email,
            is_active=body.is_active,
            must_change_password=body.must_change_password,
            password=body.password,
            platform_role=body.platform_role,
        )
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    # Reload identities for login_methods in response
    detail = await pas.user_detail(db, user.id)
    return {"user": detail["user"]}


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: uuid.UUID,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await pas.delete_user(db, admin, user_id)
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return {"ok": True}


@router.post("/users/{user_id}/platform-role")
async def set_role(
    user_id: uuid.UUID,
    body: RoleBody,
    admin: Annotated[User, Depends(require_super_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        user = await pas.set_platform_role(db, admin, user_id, body.platform_role)
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return {"user": pas._user_row(user)}


@router.get("/projects")
async def projects(
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort: str | None = Query(
        None, pattern="^(name|created_at|member_count|task_count|restricted)$"
    ),
    sort_dir: str | None = Query(None, pattern="^(asc|desc)$"),
):
    return await pas.list_projects(
        db, q=q, page=page, page_size=page_size, sort=sort, sort_dir=sort_dir
    )


@router.get("/projects/{project_id}")
async def project_card(
    project_id: uuid.UUID,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        return await pas.project_detail(db, project_id)
    except pas.PlatformError as e:
        raise _err(e)


class RestrictBody(BaseModel):
    reason: str = Field(min_length=3, max_length=2000)


@router.post("/projects/{project_id}/restrict")
async def restrict_project(
    project_id: uuid.UUID,
    body: RestrictBody,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await pas.restrict_project(db, admin, project_id, body.reason)
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return result


@router.post("/projects/{project_id}/unrestrict")
async def unrestrict_project(
    project_id: uuid.UUID,
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await pas.unrestrict_project(db, admin, project_id)
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return result


@router.get("/moderation/reports")
async def moderation_list(
    admin: Annotated[User, Depends(require_platform_moderator)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: ModerationReportStatus | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    stmt = select(ModerationReport).order_by(ModerationReport.created_at.desc())
    if status:
        stmt = stmt.where(ModerationReport.status == status)
    rows = (await db.execute(stmt.offset((page - 1) * page_size).limit(page_size))).scalars().all()
    return {
        "items": [
            {
                "id": str(r.id),
                "target_type": r.target_type.value,
                "target_id": str(r.target_id),
                "reason_code": r.reason_code,
                "status": r.status.value,
                "assignee_id": str(r.assignee_id) if r.assignee_id else None,
                "version": r.version,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ],
        "page": page,
        "page_size": page_size,
    }


class ModerationDecideBody(BaseModel):
    action: str
    note: str | None = None
    expected_version: int


@router.post("/moderation/reports/{report_id}/decide")
async def moderation_decide(
    report_id: uuid.UUID,
    body: ModerationDecideBody,
    admin: Annotated[User, Depends(require_platform_moderator)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        report = await pas.decide_report(
            db,
            admin,
            report_id,
            action=body.action,
            note=body.note,
            expected_version=body.expected_version,
        )
    except pas.PlatformError as e:
        raise _err(e)
    await db.commit()
    return {"id": str(report.id), "status": report.status.value, "version": report.version}


@router.get("/system/health")
async def system_health(
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    return await pas.system_health(db, get_settings())


@router.get("/analytics")
async def analytics(
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(30, ge=7, le=90),
):
    return await pas.analytics(db, days)


@router.get("/security/audit")
async def audit_log(
    admin: Annotated[User, Depends(require_platform_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = Query(100, ge=1, le=500),
):
    logs = (
        await db.execute(select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc()).limit(limit))
    ).scalars().all()
    return {
        "items": [
            {
                "id": str(l.id),
                "admin_id": str(l.admin_id),
                "target_user_id": str(l.target_user_id) if l.target_user_id else None,
                "action": l.action,
                "details": l.details,
                "created_at": l.created_at.isoformat() if l.created_at else None,
            }
            for l in logs
        ]
    }


@router.get("/settings")
async def get_settings_api(
    admin: Annotated[User, Depends(require_super_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    stored = await pas.get_settings_map(db)
    oauth = await provider_availability(db)
    return {
        "stored": stored,
        "oauth_providers": oauth,
        "oauth_login_methods": oauth.get("admin_flags")
        or {
            "apple": True,
            "vk": True,
            "yandex": True,
            "email_password": True,
        },
        "privacy_policy": stored.get("privacy_policy")
        or {"url": "", "text": ""},
        "support": stored.get("support")
        or {"email": "", "url": "", "telegram": ""},
    }


class SettingBody(BaseModel):
    value: dict[str, Any]


@router.put("/settings/{key}")
async def put_setting(
    key: str,
    body: SettingBody,
    admin: Annotated[User, Depends(require_super_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if not key.replace("_", "").replace("-", "").isalnum():
        raise HTTPException(status_code=400, detail={"error": {"code": "bad_key", "message": "Некорректный ключ"}})
    value = body.value
    if key == "oauth_login_methods":
        allowed = {"apple", "vk", "yandex", "email_password"}
        cleaned: dict[str, bool] = {}
        for k, v in value.items():
            if k in allowed:
                cleaned[k] = bool(v)
        if not cleaned:
            raise HTTPException(
                status_code=400,
                detail={"error": {"code": "bad_value", "message": "Нужен хотя бы один флаг способа входа"}},
            )
        value = cleaned
    elif key == "privacy_policy":
        value = {
            "url": str(value.get("url") or "")[:2000],
            "text": str(value.get("text") or "")[:20000],
        }
    elif key == "support":
        value = {
            "email": str(value.get("email") or "")[:320],
            "url": str(value.get("url") or "")[:2000],
            "telegram": str(value.get("telegram") or "")[:200],
        }
    elif key not in ("oauth_login_methods", "privacy_policy", "support"):
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "bad_key", "message": "Неизвестный ключ настройки"}},
        )
    result = await pas.put_setting(db, admin, key[:100], value)
    await db.commit()
    return result


@router.get("/me")
async def platform_me(admin: Annotated[User, Depends(require_platform_moderator)]):
    from app.api.deps import effective_platform_role

    return {
        "id": str(admin.id),
        "email": admin.email,
        "name": admin.name,
        "platform_role": effective_platform_role(admin).value,
        "legacy_role": admin.role.value,
    }
