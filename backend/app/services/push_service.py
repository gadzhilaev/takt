"""Web Push delivery via VAPID. No-ops when keys are not configured."""

from __future__ import annotations

import json
import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.models.push_subscription import PushSubscription

logger = logging.getLogger(__name__)


def vapid_configured(settings: Settings) -> bool:
    return bool(settings.VAPID_PRIVATE_KEY and settings.VAPID_PUBLIC_KEY)


async def upsert_subscription(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    endpoint: str,
    p256dh: str,
    auth: str,
    user_agent: str | None,
    session_id: uuid.UUID | None = None,
) -> PushSubscription:
    now = datetime.now(UTC)
    existing = (
        await db.execute(select(PushSubscription).where(PushSubscription.endpoint == endpoint))
    ).scalar_one_or_none()
    if existing:
        existing.user_id = user_id
        existing.p256dh = p256dh
        existing.auth = auth
        existing.user_agent = user_agent
        if session_id is not None:
            existing.session_id = session_id
        existing.updated_at = now
        return existing
    row = PushSubscription(
        user_id=user_id,
        endpoint=endpoint,
        p256dh=p256dh,
        auth=auth,
        user_agent=user_agent,
        session_id=session_id,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    return row


async def delete_subscription(db: AsyncSession, *, user_id: uuid.UUID, endpoint: str) -> bool:
    row = (
        await db.execute(
            select(PushSubscription).where(
                PushSubscription.user_id == user_id,
                PushSubscription.endpoint == endpoint,
            )
        )
    ).scalar_one_or_none()
    if not row:
        return False
    await db.delete(row)
    return True


async def send_push_to_users(
    db: AsyncSession,
    settings: Settings,
    *,
    user_ids: list[uuid.UUID],
    title: str,
    body: str | None,
    url: str | None = None,
    tag: str | None = None,
) -> int:
    """Send a Web Push and return the number of endpoints accepted by the provider."""
    if not vapid_configured(settings) or not user_ids:
        return 0
    try:
        from pywebpush import WebPushException, webpush
    except ImportError:
        logger.warning("pywebpush not installed — skip push")
        return 0

    rows = (
        (await db.execute(select(PushSubscription).where(PushSubscription.user_id.in_(user_ids))))
        .scalars()
        .all()
    )
    if not rows:
        logger.info("Web Push skipped: no subscriptions for %s recipient(s)", len(user_ids))
        return 0

    payload = json.dumps(
        {"title": title, "body": body or "", "url": url or "/projects", "tag": tag or "takt"},
        ensure_ascii=False,
    )
    vapid_claims = {"sub": settings.VAPID_SUBJECT}
    dead: list[PushSubscription] = []
    accepted = 0

    for sub in rows:
        try:
            webpush(
                subscription_info={
                    "endpoint": sub.endpoint,
                    "keys": {"p256dh": sub.p256dh, "auth": sub.auth},
                },
                data=payload,
                vapid_private_key=settings.VAPID_PRIVATE_KEY,
                vapid_claims=vapid_claims,
            )
            accepted += 1
        except WebPushException as exc:
            status = getattr(getattr(exc, "response", None), "status_code", None)
            if status in (404, 410):
                dead.append(sub)
            else:
                logger.info("webpush failed for %s: %s", sub.id, exc)
        except Exception as exc:  # noqa: BLE001
            logger.info("webpush error: %s", exc)

    for sub in dead:
        await db.delete(sub)
    logger.info("Web Push provider accepted %s/%s subscription(s)", accepted, len(rows))
    return accepted
