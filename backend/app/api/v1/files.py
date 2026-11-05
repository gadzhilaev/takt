import uuid
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import AsyncSessionLocal, get_db
from app.models.team import TeamSettings
from app.models.user import User
from app.services import attachment_service, project_service

router = APIRouter(prefix="/files", tags=["files"])


@router.get("/avatars/{user_id}")
async def get_avatar(user_id: uuid.UUID):
    async with AsyncSessionLocal() as db:
        user = await db.get(User, user_id)
        if not user or not user.avatar_path:
            raise HTTPException(status_code=404)
        path = Path(user.avatar_path)
        if not path.is_file():
            raise HTTPException(status_code=404)
        return FileResponse(path)


@router.get("/logo")
async def get_logo():
    async with AsyncSessionLocal() as db:
        team = await db.get(TeamSettings, 1)
        if not team or not team.logo_path:
            raise HTTPException(status_code=404)
        return FileResponse(team.logo_path)


async def _attachment_with_access(
    db: AsyncSession,
    user: User,
    attachment_id: uuid.UUID,
):
    att = await attachment_service.get_attachment(db, attachment_id)
    if not att or not att.task:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Файл не найден"}})
    if not att.task.project_id:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет доступа"}})
    try:
        await project_service.ensure_project_access(db, user, att.task.project_id)
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет доступа"}})
    return att


@router.get("/attachments/{attachment_id}")
async def get_attachment_file(
    attachment_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    att = await _attachment_with_access(db, user, attachment_id)
    path = attachment_service.attachment_path(att)
    if not path.is_file():
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Файл не найден"}})
    return FileResponse(
        path,
        media_type=att.content_type,
        filename=att.filename,
        content_disposition_type="inline",
    )


@router.get("/attachments/{attachment_id}/preview")
async def get_attachment_preview(
    attachment_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    att = await _attachment_with_access(db, user, attachment_id)
    prev = attachment_service.preview_path(att)
    if prev and prev.is_file():
        return FileResponse(prev, media_type="image/webp", filename=f"{Path(att.filename).stem}.webp")
    # Fallback to original if image but preview missing
    path = attachment_service.attachment_path(att)
    if attachment_service.is_image_content_type(att.content_type) and path.is_file():
        return FileResponse(path, media_type=att.content_type, filename=att.filename)
    raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Превью нет"}})
