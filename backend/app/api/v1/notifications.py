import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, verify_csrf
from app.core.config import get_settings
from app.db.session import get_db
from app.models.notification import Notification
from app.models.project import Project
from app.models.user import User
from app.services import fcm_service, push_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


class PushSubscribeIn(BaseModel):
    endpoint: str
    keys: dict[str, str]
    user_agent: str | None = None


class PushUnsubscribeIn(BaseModel):
    endpoint: str = Field(min_length=8)


class DeviceTokenIn(BaseModel):
    token: str = Field(min_length=8)
    platform: str = Field(description="ios | android")
    app_version: str | None = None


@router.get("")
async def list_notifications(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    unread_only: bool = False,
    page: int = 1,
    page_size: int = 50,
):
    q = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        q = q.where(Notification.is_read.is_(False))
    total = await db.scalar(select(func.count()).select_from(q.subquery())) or 0
    rows = (
        await db.execute(
            q.order_by(Notification.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars().all()
    unread = await db.scalar(
        select(func.count()).where(
            Notification.user_id == user.id, Notification.is_read.is_(False)
        )
    )
    project_ids = {n.project_id for n in rows if n.project_id}
    project_names: dict[uuid.UUID, str] = {}
    if project_ids:
        for pid, name in (
            await db.execute(select(Project.id, Project.name).where(Project.id.in_(project_ids)))
        ).all():
            project_names[pid] = name
    return {
        "items": [
            {
                "id": str(n.id),
                "kind": n.kind,
                "title": n.title,
                "body": n.body,
                "task_id": str(n.task_id) if n.task_id else None,
                "project_id": str(n.project_id) if n.project_id else None,
                "project_name": project_names.get(n.project_id) if n.project_id else None,
                "is_read": n.is_read,
                "created_at": n.created_at,
            }
            for n in rows
        ],
        "total": total,
        "unread": unread or 0,
    }


@router.post("/{notification_id}/read", dependencies=[Depends(verify_csrf)])
async def mark_read(
    notification_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    n = await db.get(Notification, notification_id)
    if not n or n.user_id != user.id:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}})
    n.is_read = True
    await db.commit()
    return {"ok": True}


@router.post("/read-all", dependencies=[Depends(verify_csrf)])
async def mark_all_read(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await db.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    await db.commit()
    return {"ok": True}


@router.get("/push/vapid-public-key")
async def vapid_public_key(user: Annotated[User, Depends(get_current_user)]):
    settings = get_settings()
    return {
        "public_key": settings.VAPID_PUBLIC_KEY or None,
        "configured": push_service.vapid_configured(settings),
    }


@router.post("/push/subscribe", dependencies=[Depends(verify_csrf)])
async def push_subscribe(
    body: PushSubscribeIn,
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    settings = get_settings()
    if not push_service.vapid_configured(settings):
        raise HTTPException(
            status_code=503,
            detail={"error": {"code": "push_disabled", "message": "Web Push не настроен на сервере"}},
        )
    p256dh = body.keys.get("p256dh")
    auth = body.keys.get("auth")
    if not p256dh or not auth:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "invalid_keys", "message": "Нужны keys.p256dh и keys.auth"}},
        )
    ua = body.user_agent or request.headers.get("user-agent")
    await push_service.upsert_subscription(
        db,
        user_id=user.id,
        endpoint=body.endpoint,
        p256dh=p256dh,
        auth=auth,
        user_agent=ua,
    )
    await db.commit()
    return {"ok": True}


@router.post("/push/unsubscribe", dependencies=[Depends(verify_csrf)])
async def push_unsubscribe(
    body: PushUnsubscribeIn,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await push_service.delete_subscription(db, user_id=user.id, endpoint=body.endpoint)
    await db.commit()
    return {"ok": True}


@router.post("/device-token", dependencies=[Depends(verify_csrf)])
async def register_device_token(
    body: DeviceTokenIn,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Register FCM token for mobile. Safe to call repeatedly (upsert by token)."""
    await fcm_service.upsert_device_token(
        db,
        user_id=user.id,
        token=body.token.strip(),
        platform=body.platform,
        app_version=body.app_version,
    )
    await db.commit()
    settings = get_settings()
    return {"ok": True, "fcm_configured": fcm_service.fcm_configured(settings)}


@router.delete("/device-token", dependencies=[Depends(verify_csrf)])
async def unregister_device_token(
    body: DeviceTokenIn,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await fcm_service.delete_device_token(db, user_id=user.id, token=body.token.strip())
    await db.commit()
    return {"ok": True}


async def notify_users(
    db: AsyncSession,
    *,
    user_ids: list[uuid.UUID],
    actor_id: uuid.UUID | None,
    kind: str,
    title: str,
    body: str | None = None,
    task_id: uuid.UUID | None = None,
    project_id: uuid.UUID | None = None,
) -> None:
    """Legacy helper kept for invite flow."""
    now = datetime.now(UTC)
    for uid in set(user_ids):
        if actor_id and uid == actor_id:
            continue
        db.add(
            Notification(
                user_id=uid,
                actor_id=actor_id,
                kind=kind,
                title=title,
                body=body,
                task_id=task_id,
                project_id=project_id,
                is_read=False,
                created_at=now,
            )
        )
