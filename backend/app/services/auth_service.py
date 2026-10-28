import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.models.auth import RefreshToken
from app.models.user import User


class AuthError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message


_login_attempts: dict[str, list[datetime]] = {}
_login_lock_until: dict[str, datetime] = {}


def _client_key(email: str, ip: str | None) -> str:
    return f"{email.lower()}:{ip or 'unknown'}"


def check_login_lockout(email: str, ip: str | None, max_attempts: int, lock_minutes: int) -> None:
    key = _client_key(email, ip)
    until = _login_lock_until.get(key)
    if until and until > datetime.now(UTC):
        raise AuthError("locked", "Слишком много попыток. Попробуйте позже.")
    if until and until <= datetime.now(UTC):
        _login_lock_until.pop(key, None)
        _login_attempts.pop(key, None)


def record_failed_login(email: str, ip: str | None, max_attempts: int, lock_minutes: int) -> None:
    key = _client_key(email, ip)
    now = datetime.now(UTC)
    attempts = [t for t in _login_attempts.get(key, []) if now - t < timedelta(minutes=lock_minutes)]
    attempts.append(now)
    _login_attempts[key] = attempts
    if len(attempts) >= max_attempts:
        _login_lock_until[key] = now + timedelta(minutes=lock_minutes)


def clear_login_attempts(email: str, ip: str | None) -> None:
    key = _client_key(email, ip)
    _login_attempts.pop(key, None)
    _login_lock_until.pop(key, None)


async def authenticate_user(
    db: AsyncSession,
    email: str,
    password: str,
    ip: str | None,
    max_attempts: int,
    lock_minutes: int,
) -> User:
    check_login_lockout(email, ip, max_attempts, lock_minutes)
    result = await db.execute(select(User).where(User.email == email.lower()))
    user = result.scalar_one_or_none()
    if not user or not verify_password(user.password_hash, password):
        record_failed_login(email, ip, max_attempts, lock_minutes)
        raise AuthError("invalid_credentials", "Неверный email или пароль")
    if not user.is_active:
        raise AuthError("inactive", "Учётная запись отключена")
    # Demo staff profiles (is_demo) cannot log in — except the dedicated DEMO_USER_EMAIL viewer.
    from app.core.config import get_settings

    demo_email = (get_settings().DEMO_USER_EMAIL or "").strip().lower()
    if getattr(user, "is_demo", False) and user.email.lower() != demo_email:
        raise AuthError("demo_profile", "Демонстрационный профиль недоступен для входа")
    clear_login_attempts(email, ip)
    user.last_login_at = datetime.now(UTC)
    await db.flush()
    return user


async def create_token_pair(db: AsyncSession, user: User) -> tuple[str, str, str]:
    jti = secrets.token_urlsafe(32)
    access = create_access_token(str(user.id), {"role": user.role.value})
    refresh = create_refresh_token(str(user.id), jti)
    from app.core.config import get_settings

    settings = get_settings()
    expires = datetime.now(UTC) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    db.add(RefreshToken(user_id=user.id, jti=jti, expires_at=expires))
    await db.flush()
    return access, refresh, jti


async def revoke_refresh_token(db: AsyncSession, jti: str) -> None:
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.jti == jti)
        .values(revoked_at=datetime.now(UTC))
    )


async def revoke_all_user_tokens(db: AsyncSession, user_id: uuid.UUID) -> None:
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=datetime.now(UTC))
    )


async def refresh_session(db: AsyncSession, refresh_token: str) -> tuple[str, str, User]:
    from app.core.security import decode_token

    payload = decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise AuthError("invalid_token", "Недействительный refresh-токен")
    jti = payload.get("jti")
    sub = payload.get("sub")
    if not jti or not sub:
        raise AuthError("invalid_token", "Недействительный refresh-токен")
    result = await db.execute(select(RefreshToken).where(RefreshToken.jti == jti))
    stored = result.scalar_one_or_none()
    if not stored or stored.revoked_at or stored.expires_at < datetime.now(UTC):
        raise AuthError("invalid_token", "Сессия истекла")
    user_id = uuid.UUID(sub)
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise AuthError("inactive", "Учётная запись отключена")
    await revoke_refresh_token(db, jti)
    access, new_refresh, _ = await create_token_pair(db, user)
    return access, new_refresh, user


async def change_password(
    db: AsyncSession, user: User, current: str, new_password: str
) -> None:
    if not verify_password(user.password_hash, current):
        raise AuthError("invalid_password", "Неверный текущий пароль")
    user.password_hash = hash_password(new_password)
    user.must_change_password = False
    await revoke_all_user_tokens(db, user.id)
    await db.flush()
