"""Email OTP challenges for registration and password change."""

from __future__ import annotations

import hashlib
import json
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.models.email_code import EmailCode, EmailCodePurpose
from app.services.email_service import EmailDeliveryError, is_email_configured, send_otp_email


class EmailCodeError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code


def _hash_code(*, email: str, purpose: str, code: str, secret: str) -> str:
    raw = f"{secret}:{purpose}:{email.lower().strip()}:{code.strip()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _generate_code(length: int) -> str:
    # 6 digits, no leading-zero issues for UX (still allow 000000 rarely via secrets)
    upper = 10**length
    return f"{secrets.randbelow(upper):0{length}d}"


def expose_dev_code(settings: Settings | None = None) -> bool:
    s = settings or get_settings()
    if s.ENV == "test":
        return True
    if s.DEBUG and not is_email_configured():
        return True
    return False


async def _invalidate_active(db: AsyncSession, *, email: str, purpose: EmailCodePurpose) -> None:
    now = datetime.now(UTC)
    await db.execute(
        update(EmailCode)
        .where(
            EmailCode.email == email.lower().strip(),
            EmailCode.purpose == purpose,
            EmailCode.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )


async def create_and_send_code(
    db: AsyncSession,
    *,
    email: str,
    purpose: EmailCodePurpose,
    payload: dict[str, Any],
    user_id=None,
) -> dict[str, Any]:
    settings = get_settings()
    email_norm = email.lower().strip()

    if settings.ENV == "production" and not is_email_configured():
        raise EmailCodeError(
            "email_not_configured",
            "Отправка писем не настроена на сервере",
            status_code=503,
        )

    # Resend cooldown: look at latest non-consumed for this email+purpose
    latest = await db.scalar(
        select(EmailCode)
        .where(EmailCode.email == email_norm, EmailCode.purpose == purpose)
        .order_by(EmailCode.created_at.desc())
        .limit(1)
    )
    if latest and latest.consumed_at is None:
        wait = settings.EMAIL_CODE_RESEND_SECONDS - int(
            (datetime.now(UTC) - latest.created_at).total_seconds()
        )
        if wait > 0:
            raise EmailCodeError(
                "cooldown",
                f"Повторная отправка через {wait} сек.",
                status_code=429,
            )

    await _invalidate_active(db, email=email_norm, purpose=purpose)

    code = _generate_code(settings.EMAIL_CODE_LENGTH)
    row = EmailCode(
        email=email_norm,
        purpose=purpose,
        code_hash=_hash_code(
            email=email_norm,
            purpose=purpose.value,
            code=code,
            secret=settings.SECRET_KEY,
        ),
        payload_json=json.dumps(payload, ensure_ascii=False),
        user_id=user_id,
        expires_at=datetime.now(UTC) + timedelta(minutes=settings.EMAIL_CODE_TTL_MINUTES),
    )
    db.add(row)
    await db.flush()

    try:
        await send_otp_email(to=email_norm, code=code, purpose=purpose.value)
    except EmailDeliveryError as e:
        raise EmailCodeError("email_send_failed", e.message, status_code=503) from e

    result: dict[str, Any] = {
        "ok": True,
        "expires_in": settings.EMAIL_CODE_TTL_MINUTES * 60,
        "email": email_norm,
    }
    if expose_dev_code(settings):
        result["dev_code"] = code
    return result


async def consume_code(
    db: AsyncSession,
    *,
    email: str,
    purpose: EmailCodePurpose,
    code: str,
    user_id=None,
) -> dict[str, Any]:
    settings = get_settings()
    email_norm = email.lower().strip()
    code_norm = (code or "").strip()
    if not code_norm:
        raise EmailCodeError("invalid_code", "Введите код из письма")

    row = await db.scalar(
        select(EmailCode)
        .where(
            EmailCode.email == email_norm,
            EmailCode.purpose == purpose,
            EmailCode.consumed_at.is_(None),
        )
        .order_by(EmailCode.created_at.desc())
        .limit(1)
    )
    if not row:
        raise EmailCodeError("no_challenge", "Сначала запросите код на почту")
    if user_id is not None and row.user_id is not None and row.user_id != user_id:
        raise EmailCodeError("no_challenge", "Сначала запросите код на почту")
    if row.expires_at <= datetime.now(UTC):
        row.consumed_at = datetime.now(UTC)
        await db.flush()
        raise EmailCodeError("expired", "Код истёк. Запросите новый")

    if row.attempts >= settings.EMAIL_CODE_MAX_ATTEMPTS:
        row.consumed_at = datetime.now(UTC)
        await db.flush()
        raise EmailCodeError("too_many_attempts", "Слишком много попыток. Запросите новый код")

    expected = _hash_code(
        email=email_norm,
        purpose=purpose.value,
        code=code_norm,
        secret=settings.SECRET_KEY,
    )
    if not secrets.compare_digest(expected, row.code_hash):
        row.attempts += 1
        await db.flush()
        left = settings.EMAIL_CODE_MAX_ATTEMPTS - row.attempts
        raise EmailCodeError(
            "invalid_code",
            "Неверный код" + (f". Осталось попыток: {left}" if left > 0 else ""),
        )

    row.consumed_at = datetime.now(UTC)
    await db.flush()
    try:
        return json.loads(row.payload_json or "{}")
    except json.JSONDecodeError:
        return {}
