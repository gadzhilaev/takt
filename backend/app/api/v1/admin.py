import csv
import io
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin, verify_csrf
from app.api.serializers import avatar_url
from app.core.security import generate_password, hash_password
from app.db.session import get_db
from app.models.task import AdminAuditLog
from app.models.user import User, UserRole
from app.schemas.user import (
    UserAdminCreate,
    UserAdminResetPassword,
    UserAdminResponse,
    UserAdminUpdate,
    UserCreateResult,
)
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(verify_csrf)])


def _admin_user(u: User) -> UserAdminResponse:
    return UserAdminResponse(
        id=str(u.id),
        email=u.email,
        name=u.name,
        role=u.role.value,
        is_active=u.is_active,
        must_change_password=u.must_change_password,
        avatar_url=avatar_url(u),
        created_at=u.created_at,
        last_login_at=u.last_login_at,
    )


@router.get("/users")
async def list_users(
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    search: str | None = None,
    role: UserRole | None = None,
    is_active: bool | None = None,
):
    q = select(User).order_by(User.created_at.desc())
    if search:
        like = f"%{search}%"
        q = q.where((User.name.ilike(like)) | (User.email.ilike(like)))
    if role:
        q = q.where(User.role == role)
    if is_active is not None:
        q = q.where(User.is_active == is_active)
    users = (await db.execute(q)).scalars().all()
    return {"items": [_admin_user(u) for u in users]}


@router.post("/users", response_model=UserCreateResult)
async def create_user(
    body: UserAdminCreate,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        user, temp = await admin_service.create_user_admin(
            db,
            admin,
            name=body.name,
            email=body.email,
            role=body.role,
            password=body.password,
            must_change_password=body.must_change_password,
        )
    except admin_service.AdminError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return UserCreateResult(user=_admin_user(user), temporary_password=temp)


@router.patch("/users/{user_id}")
async def update_user(
    user_id: uuid.UUID,
    body: UserAdminUpdate,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    if body.role == UserRole.member and target.role == UserRole.admin and target.id != admin.id:
        others = await admin_service.count_active_admins(db, exclude_id=target.id)
        if target.is_active and others < 1:
            raise HTTPException(
                status_code=400,
                detail={"error": {"code": "last_admin", "message": "Нельзя понизить последнего администратора"}},
            )
    if body.role == UserRole.member and target.id == admin.id:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "self", "message": "Нельзя понизить самого себя"}},
        )
    if body.name is not None:
        target.name = body.name
    if body.email is not None:
        target.email = body.email.lower()
    if body.role is not None:
        target.role = body.role
    await admin_service.audit(db, admin.id, "user_updated", target.id)
    await db.commit()
    return {"user": _admin_user(target)}


@router.post("/users/{user_id}/reset-password")
async def reset_password(
    user_id: uuid.UUID,
    body: UserAdminResetPassword,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    temp: str | None = None
    pwd = body.password
    if body.generate or not pwd:
        pwd = generate_password()
        temp = pwd
    target.password_hash = hash_password(pwd)
    target.must_change_password = body.must_change_password
    await admin_service.audit(db, admin.id, "password_reset", target.id)
    await db.commit()
    return {"temporary_password": temp, "user": _admin_user(target)}


@router.post("/users/{user_id}/deactivate")
async def deactivate(
    user_id: uuid.UUID,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    try:
        await admin_service.deactivate_user(db, admin, target)
    except admin_service.AdminError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"user": _admin_user(target)}


@router.post("/users/{user_id}/activate")
async def activate(
    user_id: uuid.UUID,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    await admin_service.activate_user(db, admin, target)
    await db.commit()
    return {"user": _admin_user(target)}


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: uuid.UUID,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    reassign_to: uuid.UUID | None = Query(default=None),
):
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    try:
        await admin_service.delete_user(db, admin, target, reassign_to)
    except admin_service.AdminError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True}


@router.post("/users/import-csv")
async def import_csv(
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile,
):
    content = (await file.read()).decode("utf-8-sig")
    rows = admin_service.parse_users_csv(content)
    results = []
    for row in rows:
        role = UserRole.admin if row["role"] == "admin" else UserRole.member
        try:
            user, temp = await admin_service.create_user_admin(
                db,
                admin,
                name=row["name"],
                email=row["email"],
                role=role,
                password=None,
                must_change_password=True,
            )
            results.append(
                {
                    "name": user.name,
                    "email": user.email,
                    "role": user.role.value,
                    "password": temp,
                }
            )
        except admin_service.AdminError:
            results.append({"name": row["name"], "email": row["email"], "error": "skip"})
    await db.commit()
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=["name", "email", "role", "password"])
    writer.writeheader()
    for r in results:
        writer.writerow(r)
    out.seek(0)
    return StreamingResponse(
        iter([out.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=import_result.csv"},
    )


@router.get("/audit-log")
async def audit_log(
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    logs = (
        await db.execute(select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc()).limit(200))
    ).scalars().all()
    return {
        "items": [
            {
                "id": str(l.id),
                "admin_id": str(l.admin_id),
                "target_user_id": str(l.target_user_id) if l.target_user_id else None,
                "action": l.action,
                "details": l.details,
                "created_at": l.created_at,
            }
            for l in logs
        ]
    }
