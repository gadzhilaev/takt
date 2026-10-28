import uuid
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, verify_csrf
from app.api.serializers import avatar_url
from app.core.config import get_settings
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import UserPublic
from app.schemas.user import ProfileUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("")
async def list_users(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    users = (await db.execute(select(User).where(User.is_active.is_(True)).order_by(User.name))).scalars().all()
    return {
        "items": [
            UserPublic(
                id=str(u.id),
                email=u.email,
                name=u.name,
                role=u.role.value,
                avatar_url=avatar_url(u),
                must_change_password=False,
            )
            for u in users
        ]
    }


@router.patch("/me", dependencies=[Depends(verify_csrf)])
async def update_profile(
    body: ProfileUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if body.name is not None:
        user.name = body.name
    await db.commit()
    return {
        "user": UserPublic(
            id=str(user.id),
            email=user.email,
            name=user.name,
            role=user.role.value,
            avatar_url=avatar_url(user),
            must_change_password=user.must_change_password,
        )
    }


@router.post("/me/avatar", dependencies=[Depends(verify_csrf)])
async def upload_avatar(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    settings = get_settings()
    if file.size and file.size > settings.MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=400, detail={"error": {"code": "too_large", "message": "Файл слишком большой"}})
    content = await file.read()
    if len(content) > settings.MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=400, detail={"error": {"code": "too_large", "message": "Файл слишком большой"}})
    avatars_dir = Path(settings.UPLOAD_DIR) / "avatars"
    avatars_dir.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename or "avatar.png").suffix or ".png"
    path = avatars_dir / f"{user.id}{ext}"
    path.write_bytes(content)
    user.avatar_path = str(path)
    await db.commit()
    return {"avatar_url": avatar_url(user)}
