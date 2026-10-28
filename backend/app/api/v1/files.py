import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models.team import TeamSettings
from app.models.user import User

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
