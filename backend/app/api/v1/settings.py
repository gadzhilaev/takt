import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_admin, verify_csrf
from app.db.session import get_db
from app.models.team import TaskStatus, TeamSettings
from app.models.user import User
from app.api.serializers import status_to_out
from app.schemas.task import StatusOut

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("/team")
async def get_team(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    team = await db.get(TeamSettings, 1)
    logo_url = f"/api/v1/files/logo" if team and team.logo_path else None
    return {
        "team_name": team.team_name if team else "Моя команда",
        "logo_url": logo_url,
    }


@router.patch("/team", dependencies=[Depends(verify_csrf)])
async def update_team(
    body: dict,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    team = await db.get(TeamSettings, 1)
    if not team:
        team = TeamSettings(id=1)
        db.add(team)
    if "team_name" in body:
        team.team_name = body["team_name"]
    await db.commit()
    return {"team_name": team.team_name}


@router.get("/statuses")
async def list_statuses(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    project_id: uuid.UUID | None = None,
):
    q = select(TaskStatus).order_by(TaskStatus.position)
    if project_id:
        q = q.where(TaskStatus.project_id == project_id)
    rows = (await db.execute(q)).scalars().all()
    return {"items": [status_to_out(s) for s in rows]}


@router.post("/statuses", dependencies=[Depends(verify_csrf)])
async def create_status(
    body: dict,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    project_id = body.get("project_id")
    q = select(TaskStatus.position).order_by(TaskStatus.position.desc())
    if project_id:
        q = q.where(TaskStatus.project_id == uuid.UUID(str(project_id)))
    max_pos = await db.scalar(q)
    status = TaskStatus(
        name=body["name"],
        color=body.get("color", "#6366f1"),
        position=float(body.get("position", (max_pos or 0) + 1)),
        is_done=bool(body.get("is_done", False)),
        project_id=uuid.UUID(str(project_id)) if project_id else None,
    )
    db.add(status)
    await db.commit()
    return {"status": status_to_out(status)}


@router.patch("/statuses/{status_id}", dependencies=[Depends(verify_csrf)])
async def update_status(
    status_id: uuid.UUID,
    body: dict,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    status = await db.get(TaskStatus, status_id)
    if not status:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    for key in ("name", "color", "position", "is_done"):
        if key in body:
            setattr(status, key, body[key] if key != "position" else float(body[key]))
    await db.commit()
    return {"status": status_to_out(status)}


@router.delete("/statuses/{status_id}", dependencies=[Depends(verify_csrf)])
async def delete_status(
    status_id: uuid.UUID,
    admin: Annotated[User, Depends(require_admin)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from app.models.task import Task

    status = await db.get(TaskStatus, status_id)
    if not status:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найден"}})
    cnt = await db.scalar(select(Task.id).where(Task.status_id == status_id).limit(1))
    if cnt:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "in_use", "message": "Статус используется в задачах"}},
        )
    await db.delete(status)
    await db.commit()
    return {"ok": True}
