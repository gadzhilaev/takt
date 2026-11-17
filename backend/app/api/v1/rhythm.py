"""Rhythm API: today's check-in, answers, own history, answer from a push notification."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, verify_csrf
from app.api.v1.tasks import _task_out
from app.core.limiter import limiter
from app.db.session import get_db
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.rhythm import CheckinAnswer, CheckinStatus, RhythmCheckin
from app.models.task import Task
from app.models.user import User
from app.services import rhythm_service, task_service
from app.services.rhythm_service import RhythmError
from app.services.websocket_hub import ws_manager

router = APIRouter(prefix="/rhythm", tags=["rhythm"])

AnswerValue = Literal["done", "in_progress", "blocked"]


class AnswerIn(BaseModel):
    task_id: uuid.UUID
    answer: AnswerValue
    reason: str | None = Field(default=None, max_length=280)


class AnswerBody(BaseModel):
    answers: list[AnswerIn] = Field(min_length=1, max_length=20)


class PushAnswerBody(BaseModel):
    checkin_id: uuid.UUID
    task_id: uuid.UUID
    answer: AnswerValue
    reason: str | None = Field(default=None, max_length=280)
    token: str = Field(min_length=10, max_length=200)


def _http(e: RhythmError) -> HTTPException:
    return HTTPException(
        status_code=e.status_code, detail={"error": {"code": e.code, "message": e.message}}
    )


async def _checkin_out(db: AsyncSession, checkin: RhythmCheckin) -> dict:
    project = await db.get(Project, checkin.project_id)
    task_ids = [i.task_id for i in checkin.items]
    tasks = {
        t.id: t
        for t in (
            await db.execute(
                select(Task).options(selectinload(Task.status)).where(Task.id.in_(task_ids))
            )
        ).scalars()
    } if task_ids else {}
    items = []
    for i in checkin.items:
        t = tasks.get(i.task_id)
        if t is None or t.deleted_at is not None:
            continue
        items.append(
            {
                "task_id": str(i.task_id),
                "title": t.title,
                "priority": t.priority.value,
                "due_date": t.due_date,
                "status": (
                    {"id": str(t.status.id), "name": t.status.name, "is_done": t.status.is_done}
                    if t.status
                    else None
                ),
                "blocked_reason": t.blocked_reason if t.blocked_at else None,
                "answer": i.answer,
                "reason": i.reason,
                "answered_at": i.answered_at,
            }
        )
    return {
        "id": str(checkin.id),
        "project": {"id": str(project.id), "name": project.name} if project else None,
        "date": checkin.date.isoformat(),
        "status": checkin.status,
        "created_at": checkin.created_at,
        "answered_at": checkin.answered_at,
        "items": items,
        # Scoped token for the home-screen widget / Live Activity (this check-in, today only).
        # Only ever returned to the owner: every endpoint here loads own check-ins only.
        "action_token": rhythm_service.scoped_action_token(checkin),
        "action_path": "/api/v1/rhythm/push-answer",
    }


async def _member_project_ids(db: AsyncSession, user: User) -> list[uuid.UUID]:
    return list(
        (
            await db.scalars(
                select(ProjectMember.project_id).where(
                    ProjectMember.user_id == user.id,
                    ProjectMember.role.in_([ProjectMemberRole.admin, ProjectMemberRole.member]),
                )
            )
        ).all()
    )


@router.get("/checkins/current")
async def current_checkins(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    project_id: uuid.UUID | None = None,
):
    """Today's check-ins (per project local day). ``pending`` first."""
    project_ids = await _member_project_ids(db, user)
    if project_id is not None:
        project_ids = [p for p in project_ids if p == project_id]
    if not project_ids:
        return {"checkins": [], "pending": 0, "startable_project_ids": []}
    since = (datetime.now(UTC) - timedelta(days=2)).date()
    rows = (
        await db.execute(
            select(RhythmCheckin)
            .options(selectinload(RhythmCheckin.items))
            .where(
                RhythmCheckin.user_id == user.id,
                RhythmCheckin.project_id.in_(project_ids),
                RhythmCheckin.date >= since,
                RhythmCheckin.status != CheckinStatus.skipped.value,
            )
            .order_by(RhythmCheckin.created_at.desc())
        )
    ).scalars().all()
    out: list[dict] = []
    for c in rows:
        project = await db.get(Project, c.project_id)
        if project is None or c.date != rhythm_service.local_today(project):
            continue
        data = await _checkin_out(db, c)
        if data["items"]:
            out.append(data)
    out.sort(key=lambda c: (c["status"] != CheckinStatus.pending.value, c["project"]["name"]))
    startable = await rhythm_service.startable_project_ids(db, user)
    if project_id is not None:
        startable = [p for p in startable if p == project_id]
    return {
        "checkins": out,
        "pending": sum(1 for c in out if c["status"] == CheckinStatus.pending.value),
        # Projects where the person can start today's check-in by hand (no check-in yet).
        "startable_project_ids": [str(p) for p in startable],
    }


@router.get("/checkins/history")
async def checkin_history(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = Query(default=30, ge=1, le=100),
):
    project_ids = await _member_project_ids(db, user)
    if not project_ids:
        return {"items": []}
    rows = (
        await db.execute(
            select(RhythmCheckin)
            .options(selectinload(RhythmCheckin.items))
            .where(RhythmCheckin.user_id == user.id, RhythmCheckin.project_id.in_(project_ids))
            .order_by(RhythmCheckin.date.desc(), RhythmCheckin.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    return {"items": [await _checkin_out(db, c) for c in rows]}


@router.get("/checkins/{checkin_id}")
async def get_checkin(
    checkin_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        checkin = await rhythm_service.load_checkin_for(db, user, checkin_id)
    except RhythmError as e:
        raise _http(e) from e
    return {"checkin": await _checkin_out(db, checkin)}


async def _commit_and_broadcast(
    db: AsyncSession, applied: list[rhythm_service.AppliedAnswer]
) -> None:
    await db.commit()
    for a in applied:
        task = await task_service.get_task(db, a.task_id)
        if task is None:
            continue
        out = await _task_out(db, task)
        event = "task.moved" if a.moved else "task.updated"
        await ws_manager.broadcast(event, {"task": out.model_dump(mode="json")})


@router.post("/checkins/{checkin_id}/answer", dependencies=[Depends(verify_csrf)])
async def answer_checkin(
    checkin_id: uuid.UUID,
    body: AnswerBody,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Answer some or all tasks of an own check-in."""
    try:
        checkin = await rhythm_service.load_checkin_for(db, user, checkin_id)
        applied = await rhythm_service.answer_checkin(
            db,
            user=user,
            checkin=checkin,
            answers=[(a.task_id, CheckinAnswer(a.answer), a.reason) for a in body.answers],
        )
    except RhythmError as e:
        await db.rollback()
        raise _http(e) from e
    await _commit_and_broadcast(db, applied)
    checkin = await rhythm_service.load_checkin_for(db, user, checkin_id)
    return {"checkin": await _checkin_out(db, checkin)}


@router.post("/checkins/start", dependencies=[Depends(verify_csrf)])
async def start_checkin(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """«Пройти чек-ин сейчас»: today's check-in by hand (no push). Existing one is returned."""
    try:
        checkin = await rhythm_service.start_checkin_now(db, user=user, project_id=project_id)
    except RhythmError as e:
        await db.rollback()
        raise _http(e) from e
    await db.commit()
    checkin = await rhythm_service.load_checkin_for(db, user, checkin.id)
    return {"checkin": await _checkin_out(db, checkin)}


@router.post("/push-answer")
@limiter.limit("30/minute")
async def push_answer(
    request: Request,
    body: PushAnswerBody,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Answer one task straight from a notification action (no app session needed).

    Authorized by the one-time token from the push payload: only this check-in, only today.
    """
    try:
        checkin, user = await rhythm_service.checkin_by_push_token(
            db, body.checkin_id, body.token
        )
        applied = await rhythm_service.answer_checkin(
            db,
            user=user,
            checkin=checkin,
            answers=[(body.task_id, CheckinAnswer(body.answer), body.reason)],
        )
    except RhythmError as e:
        await db.rollback()
        raise _http(e) from e
    await _commit_and_broadcast(db, applied)
    return {"ok": True, "status": checkin.status}

