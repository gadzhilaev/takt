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
    session_id: uuid.UUID | None = None,
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
        if session_id is not None:
            existing.session_id = session_id
        existing.updated_at = now
        return existing
    row = DevicePushToken(
        user_id=user_id,
        token=token,
        platform=plat,
        app_version=app_version,
        session_id=session_id,
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
        (await db.execute(select(DevicePushToken).where(DevicePushToken.user_id == user_id)))
        .scalars()
        .all()
    )
    for row in rows:
        await db.delete(row)


def build_message(
    messaging,
    *,
    platform: str,
    token: str,
    title: str,
    body: str | None,
    data: dict[str, str] | None,
    apns_category: str | None = None,
    android_data_only: bool = False,
):
    payload = dict(data or {})
    if android_data_only and (platform or "").lower() == "android":
        payload.setdefault("title", title)
        payload.setdefault("body", body or "")
        return messaging.Message(
            data=payload,
            token=token,
            android=messaging.AndroidConfig(priority="high"),
        )
    apns = None
    if apns_category:
        apns = messaging.APNSConfig(
            payload=messaging.APNSPayload(aps=messaging.Aps(category=apns_category))
        )
    return messaging.Message(
        notification=messaging.Notification(title=title, body=body or ""),
        data=payload,
        token=token,
        apns=apns,
    )


async def send_fcm_to_users(
    db: AsyncSession,
    settings: Settings,
    *,
    user_ids: list[uuid.UUID],
    title: str,
    body: str | None,
    data: dict[str, str] | None = None,
    apns_category: str | None = None,
    android_data_only: bool = False,
) -> int:
    """Send to every device of ``user_ids``.

    ``apns_category`` — iOS notification category (action buttons registered by the app).
    ``android_data_only`` — Android gets a high-priority data message (title/body in data);
    the app shows the notification itself with action buttons.
    """
    if not user_ids:
        return 0
    if not _ensure_firebase(settings):
        logger.info("FCM skipped: Firebase is not configured")
        return 0
    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase-admin not installed — skip FCM")
        return 0

    rows = (
        (await db.execute(select(DevicePushToken).where(DevicePushToken.user_id.in_(user_ids))))
        .scalars()
        .all()
    )
    if not rows:
        logger.info("FCM skipped: no device tokens for %s recipient(s)", len(user_ids))
        return 0

    dead: list[DevicePushToken] = []
    accepted = 0
    for row in rows:
        message = build_message(
            messaging,
            platform=row.platform,
            token=row.token,
            title=title,
            body=body,
            data=data,
            apns_category=apns_category,
            android_data_only=android_data_only,
        )
        try:
            messaging.send(message)
            accepted += 1
        except Exception as exc:  # noqa: BLE001
            msg = str(exc).lower()
            if "not-registered" in msg or "invalid-registration" in msg or "unregistered" in msg:
                dead.append(row)
            else:
                logger.info("FCM failed for %s: %s", row.id, exc)
    for row in dead:
        await db.delete(row)
    logger.info("FCM provider accepted %s/%s device token(s)", accepted, len(rows))
    return accepted
