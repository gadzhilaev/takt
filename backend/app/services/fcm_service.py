"""Firebase Cloud Messaging for iOS/Android. No-ops when credentials are missing."""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.models.device_push_token import DevicePushToken

logger = logging.getLogger(__name__)

_firebase_ready: bool | None = None


def fcm_configured(settings: Settings) -> bool:
    if not settings.FCM_ENABLED:
        return False
    path = (settings.FIREBASE_CREDENTIALS_FILE or "").strip()
    return bool(path and Path(path).is_file())


def _ensure_firebase(settings: Settings) -> bool:
    global _firebase_ready
    if _firebase_ready is not None:
        return _firebase_ready
    if not fcm_configured(settings):
        _firebase_ready = False
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_FILE)
            firebase_admin.initialize_app(cred)
        _firebase_ready = True
    except Exception as exc:  # noqa: BLE001
        logger.warning("Firebase init failed: %s", exc)
        _firebase_ready = False
    return _firebase_ready


async def upsert_device_token(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    token: str,
    platform: str,
    app_version: str | None = None,
) -> DevicePushToken:
    now = datetime.now(UTC)
    plat = platform.lower().strip()
    if plat not in ("ios", "android"):
        plat = "android"
    existing = (
        await db.execute(select(DevicePushToken).where(DevicePushToken.token == token))
    ).scalar_one_or_none()
    if existing:
        existing.user_id = user_id
        existing.platform = plat
        existing.app_version = app_version
        existing.updated_at = now
        return existing
    row = DevicePushToken(
        user_id=user_id,
        token=token,
        platform=plat,
        app_version=app_version,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    return row


async def delete_device_token(db: AsyncSession, *, user_id: uuid.UUID, token: str) -> bool:
    row = (
        await db.execute(
            select(DevicePushToken).where(
                DevicePushToken.user_id == user_id,
                DevicePushToken.token == token,
            )
        )
    ).scalar_one_or_none()
    if not row:
        return False
    await db.delete(row)
    return True


async def delete_all_for_user(db: AsyncSession, *, user_id: uuid.UUID) -> None:
    rows = (
        await db.execute(select(DevicePushToken).where(DevicePushToken.user_id == user_id))
    ).scalars().all()
    for row in rows:
        await db.delete(row)


async def send_fcm_to_users(
    db: AsyncSession,
    settings: Settings,
    *,
    user_ids: list[uuid.UUID],
    title: str,
    body: str | None,
    data: dict[str, str] | None = None,
) -> None:
    if not user_ids or not _ensure_firebase(settings):
        return
    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase-admin not installed — skip FCM")
        return

    rows = (
        await db.execute(select(DevicePushToken).where(DevicePushToken.user_id.in_(user_ids)))
    ).scalars().all()
    if not rows:
        return

    dead: list[DevicePushToken] = []
    for row in rows:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body or ""),
            data=data or {},
            token=row.token,
        )
        try:
            messaging.send(message)
        except Exception as exc:  # noqa: BLE001
            msg = str(exc).lower()
            if "not-registered" in msg or "invalid-registration" in msg or "unregistered" in msg:
                dead.append(row)
            else:
                logger.info("FCM failed for %s: %s", row.id, exc)
    for row in dead:
        await db.delete(row)
