import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_session_id, get_current_user, verify_csrf
from app.core.config import get_settings
from app.db.session import get_db
from app.models.device_push_token import DevicePushToken
from app.models.notification import Notification
from app.models.project import Project
from app.models.push_subscription import PushSubscription
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
    explicit_opt_in: bool = False


def _browser_label(user_agent: str | None) -> str:
    ua = (user_agent or "").lower()
    if "edg/" in ua:
        browser = "Microsoft Edge"
    elif "firefox/" in ua:
        browser = "Firefox"
    elif "chrome/" in ua or "crios/" in ua:
        browser = "Chrome"
    elif "safari/" in ua:
        browser = "Safari"
    else:
        browser = "Браузер"
    if "iphone" in ua or "ipad" in ua:
        os_name = " · iOS"
    elif "android" in ua:
        os_name = " · Android"
    elif "windows" in ua:
        os_name = " · Windows"
    elif "mac os" in ua or "macintosh" in ua:
        os_name = " · macOS"
    elif "linux" in ua:
        os_name = " · Linux"
    else:
        os_name = ""
    return browser + os_name


@router.get("/devices")
async def list_push_devices(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    browsers = (
        (await db.execute(select(PushSubscription).where(PushSubscription.user_id == user.id)))
        .scalars()
        .all()
    )
    apps = (
        (await db.execute(select(DevicePushToken).where(DevicePushToken.user_id == user.id)))
        .scalars()
        .all()
    )
    return {
        "items": [
            *[
                {
                    "id": str(row.id),
                    "kind": "browser",
                    "label": _browser_label(row.user_agent),
                    "created_at": row.created_at,
                    "last_activity_at": row.updated_at,
                }
                for row in browsers
            ],
            *[
                {
                    "id": str(row.id),
                    "kind": "app",
                    "label": "Приложение · " + row.platform.capitalize(),
                    "app_version": row.app_version,
                    "created_at": row.created_at,
                    "last_activity_at": row.updated_at,
                }
                for row in apps
            ],
        ]
    }


@router.delete("/devices/{kind}/{device_id}", dependencies=[Depends(verify_csrf)])
async def revoke_push_device(
    kind: str,
    device_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    model = PushSubscription if kind == "browser" else DevicePushToken if kind == "app" else None
    if model is None:
        raise HTTPException(
            status_code=404,
            detail={"error": {"code": "not_found", "message": "Устройство не найдено"}},
        )
    row = await db.scalar(select(model).where(model.id == device_id, model.user_id == user.id))
    if row is None:
        raise HTTPException(
            status_code=404,
            detail={"error": {"code": "not_found", "message": "Устройство не найдено"}},
        )
    await db.delete(row)
    await db.commit()
    return {"ok": True}


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
        (
            await db.execute(
                q.order_by(Notification.created_at.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        .scalars()
        .all()
    )
    unread = await db.scalar(
        select(func.count()).where(Notification.user_id == user.id, Notification.is_read.is_(False))
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
        raise HTTPException(
            status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}}
        )
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


@router.get("/push/status")
async def push_status(
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    session_id = get_current_session_id(request)
    user_agent = request.headers.get("user-agent")
    conditions = []
    if session_id:
        conditions.append(PushSubscription.session_id == session_id)
    if user_agent:
        conditions.append(
            (PushSubscription.session_id.is_(None))
            & (PushSubscription.user_agent == user_agent[:512])
        )
    registered = False
    if conditions:
        registered = bool(
            await db.scalar(
                select(PushSubscription.id)
                .where(PushSubscription.user_id == user.id, or_(*conditions))
                .limit(1)
            )
        )
    return {"subscribed": registered}


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
            detail={
                "error": {"code": "push_disabled", "message": "Web Push не настроен на сервере"}
            },
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
        session_id=get_current_session_id(request),
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
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Register FCM token for mobile. Safe to call repeatedly (upsert by token)."""
    if not body.explicit_opt_in:
        raise HTTPException(
            status_code=403,
            detail={
                "error": {
                    "code": "push_opt_in_required",
                    "message": "Сначала явно включите push-уведомления",
                }
            },
        )
    await fcm_service.upsert_device_token(
        db,
        user_id=user.id,
        token=body.token.strip(),
        platform=body.platform,
        app_version=body.app_version,
        session_id=get_current_session_id(request),
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
