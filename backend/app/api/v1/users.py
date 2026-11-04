import uuid
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ACCESS_COOKIE, REFRESH_COOKIE, get_current_user, verify_csrf
from app.api.serializers import avatar_url
from app.core.config import get_settings
from app.core.csrf import CSRF_COOKIE
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import UserPublic
from app.schemas.user import ProfileUpdate
from app.services.account_service import AccountError, delete_own_account

router = APIRouter(prefix="/users", tags=["users"])

ALLOWED_AVATAR_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_AVATAR_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}


def _public(user: User) -> UserPublic:
    return UserPublic(
        id=str(user.id),
        email=user.email,
        name=user.name,
        role=user.role.value,
        avatar_url=avatar_url(user),
        must_change_password=user.must_change_password,
    )


@router.get("")
async def list_users(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str | None = None,
    exclude_project_id: uuid.UUID | None = None,
):
    """List active users. Optional q filters by name/email; exclude_project_id hides members."""
    from sqlalchemy import or_
    from app.models.project import ProjectMember

    stmt = select(User).where(User.is_active.is_(True))
    # Hide demo-only profiles from ordinary users; demo viewer may search within demo.
    if not getattr(user, "is_demo", False):
        stmt = stmt.where(User.is_demo.is_(False))
    if q and q.strip():
        needle = f"%{q.strip().lower()}%"
        stmt = stmt.where(or_(User.name.ilike(needle), User.email.ilike(needle)))
    if exclude_project_id is not None:
        member_ids = select(ProjectMember.user_id).where(ProjectMember.project_id == exclude_project_id)
        stmt = stmt.where(User.id.not_in(member_ids))
    users = (await db.execute(stmt.order_by(User.name).limit(50))).scalars().all()
    return {"items": [_public(u) for u in users]}


@router.patch("/me", dependencies=[Depends(verify_csrf)])
async def update_profile(
    body: ProfileUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if body.name is not None:
        user.name = body.name.strip()
    if body.email is not None:
        email = str(body.email).lower().strip()
        if email != user.email:
            taken = await db.scalar(select(User.id).where(User.email == email, User.id != user.id))
            if taken:
                raise HTTPException(
                    status_code=400,
                    detail={"error": {"code": "email_taken", "message": "Email уже занят"}},
                )
            # SMTP confirmation not configured — apply email immediately with note in response.
            user.email = email
    await db.commit()
    await db.refresh(user)
    return {
        "user": _public(user),
        "email_confirmation": "not_configured",
    }


@router.post("/me/avatar", dependencies=[Depends(verify_csrf)])
async def upload_avatar(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    settings = get_settings()
    content_type = (file.content_type or "").lower()
    ext = Path(file.filename or "avatar.png").suffix.lower() or ".png"
    if content_type and content_type not in ALLOWED_AVATAR_TYPES:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "invalid_type", "message": "Допустимы JPEG, PNG, WebP, GIF"}},
        )
    if ext not in ALLOWED_AVATAR_EXT:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "invalid_type", "message": "Недопустимое расширение файла"}},
        )
    content = await file.read()
    if len(content) > min(settings.MAX_UPLOAD_BYTES, 2 * 1024 * 1024):
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "too_large", "message": "Аватар не больше 2 МБ"}},
        )
    if len(content) < 32:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "invalid_file", "message": "Пустой или повреждённый файл"}},
        )
    avatars_dir = Path(settings.UPLOAD_DIR) / "avatars"
    avatars_dir.mkdir(parents=True, exist_ok=True)
    # remove old files for this user
    for old in avatars_dir.glob(f"{user.id}.*"):
        old.unlink(missing_ok=True)
    path = avatars_dir / f"{user.id}{ext}"
    path.write_bytes(content)
    user.avatar_path = str(path)
    await db.commit()
    return {"avatar_url": avatar_url(user)}


@router.delete("/me/avatar", dependencies=[Depends(verify_csrf)])
async def delete_avatar(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if user.avatar_path:
        Path(user.avatar_path).unlink(missing_ok=True)
    user.avatar_path = None
    await db.commit()
    return {"avatar_url": None}


@router.delete("/me", dependencies=[Depends(verify_csrf)])
async def delete_me(
    response: Response,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Self-service account deletion / de-identification for store compliance."""
    try:
        await delete_own_account(db, user)
        await db.commit()
    except AccountError as e:
        await db.rollback()
        detail: dict = {"error": {"code": e.code, "message": e.message}}
        if e.projects:
            detail["error"]["projects"] = e.projects
        raise HTTPException(status_code=e.status_code, detail=detail) from e

    settings = get_settings()
    cookie_opts: dict = {"path": "/"}
    if settings.COOKIE_DOMAIN:
        cookie_opts["domain"] = settings.COOKIE_DOMAIN
    response.delete_cookie(ACCESS_COOKIE, **cookie_opts)
    response.delete_cookie(REFRESH_COOKIE, **cookie_opts)
    response.delete_cookie(CSRF_COOKIE, **cookie_opts)
    return {"ok": True, "message": "Аккаунт удалён"}
