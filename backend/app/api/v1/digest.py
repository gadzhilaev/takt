"""Digest («Сводка») API: summary for any period, member subscription."""

from __future__ import annotations

import uuid
from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, verify_csrf
from app.db.session import get_db
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.user import User
from app.services import digest_service, project_service
from app.services.digest_service import DigestError

router = APIRouter(prefix="/projects", tags=["digest"])


class SubscriptionBody(BaseModel):
    subscribed: bool


def _forbidden() -> HTTPException:
    return HTTPException(
        status_code=403, detail={"error": {"code": "forbidden", "message": "Нет доступа к проекту"}}
    )


async def _membership(db: AsyncSession, user: User, project_id: uuid.UUID) -> ProjectMember:
    try:
        await project_service.ensure_project_access(db, user, project_id)
    except PermissionError as e:
        raise _forbidden() from e
    member = await db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id, ProjectMember.user_id == user.id
        )
    )
    if member is None:  # workspace = membership only (even for legacy admins)
        raise _forbidden()
    return member


@router.get("/{project_id}/digest")
async def get_digest(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    period: Literal["day", "week", "month"] = "week",
    end: Annotated[date | None, Query(alias="date")] = None,
):
    """Summary for a rolling period ending on ``date`` (project timezone, default today).

    Everyone in the project sees the summary; per-member rhythm details — only admins.
    """
    member = await _membership(db, user, project_id)
    project = await db.get(Project, project_id)
    if project is None:
        raise HTTPException(
            status_code=404, detail={"error": {"code": "not_found", "message": "Проект не найден"}}
        )
    is_admin = member.role == ProjectMemberRole.admin
    try:
        digest = await digest_service.build_digest(
            db, project, kind=period, end_day=end, include_members=is_admin
        )
    except DigestError as e:
        raise HTTPException(
            status_code=e.status_code, detail={"error": {"code": e.code, "message": e.message}}
        ) from e
    digest["viewer"] = {"is_admin": is_admin, "subscribed": bool(member.digest_subscribed)}
    digest["schedule"] = {
        "daily": bool(project.digest_daily),
        "weekly": bool(project.digest_weekly),
        "time": project.digest_time.strftime("%H:%M") if project.digest_time else "18:00",
    }
    return {"digest": digest}


@router.put("/{project_id}/digest-subscription", dependencies=[Depends(verify_csrf)])
async def set_subscription(
    project_id: uuid.UUID,
    body: SubscriptionBody,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Own subscription to the project digest (on by default for every member)."""
    member = await _membership(db, user, project_id)
    member.digest_subscribed = body.subscribed
    await db.commit()
    return {"subscribed": body.subscribed}
