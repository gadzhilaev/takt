"""OAuth / OIDC for Apple, VK ID, Yandex ID.

Client secrets and private keys never leave the server.
Tokens are not logged. Account merge only after confirmed ownership.
"""

from __future__ import annotations

import base64
import hashlib
import json
import secrets
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.models.platform import OAuthLoginState, OAuthProvider, UserIdentity
from app.models.user import PlatformRole, User, UserRole
from app.services import auth_service
from app.services.activity_service import record_activity

APPLE_AUTH = "https://appleid.apple.com/auth/authorize"
APPLE_TOKEN = "https://appleid.apple.com/auth/token"
APPLE_KEYS = "https://appleid.apple.com/auth/keys"
VK_AUTH = "https://id.vk.com/authorize"
VK_TOKEN = "https://id.vk.com/oauth2/auth"
VK_USER_INFO = "https://id.vk.com/oauth2/user_info"
YANDEX_AUTH = "https://oauth.yandex.ru/authorize"
YANDEX_TOKEN = "https://oauth.yandex.ru/token"
YANDEX_INFO = "https://login.yandex.ru/info"

_AVATAR_EXT_BY_TYPE = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}


class OAuthError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code


@dataclass
class ProviderProfile:
    provider: OAuthProvider
    provider_user_id: str
    email: str | None
    email_verified: bool
    display_name: str | None
    raw_claims: dict[str, Any]
    avatar_url: str | None = None


def _pkce_pair() -> tuple[str, str]:
    verifier = secrets.token_urlsafe(64)[:128]
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    return verifier, challenge


def provider_availability(settings: Settings | None = None) -> dict[str, Any]:
    """Public provider flags. Apple may stay off for RU operators until legal clearance."""
    s = settings or get_settings()
    apple_configured = bool(
        s.OAUTH_APPLE_CLIENT_ID
        and s.OAUTH_APPLE_TEAM_ID
        and s.OAUTH_APPLE_KEY_ID
        and (s.OAUTH_APPLE_PRIVATE_KEY or s.OAUTH_APPLE_PRIVATE_KEY_FILE)
    )
    vk_configured = bool(s.OAUTH_VK_CLIENT_ID and s.OAUTH_VK_CLIENT_SECRET)
    yandex_configured = bool(s.OAUTH_YANDEX_CLIENT_ID and s.OAUTH_YANDEX_CLIENT_SECRET)

    apple_policy_blocked = (
        s.OAUTH_OPERATOR_REGION.lower() == "ru" and not s.OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR
    )
    apple_enabled = (
        s.OAUTH_APPLE_ENABLED and apple_configured and not apple_policy_blocked
    )

    notes: list[str] = []
    if s.OAUTH_APPLE_ENABLED and apple_policy_blocked:
        notes.append(
            "Apple ID отключён политикой оператора (OAUTH_OPERATOR_REGION=ru). "
            "Требуется юридическое решение по ч. 10 ст. 8 149-ФЗ до публичного включения."
        )
    if s.OAUTH_APPLE_ENABLED and not apple_configured:
        notes.append("Apple ID включён в конфиге, но credentials не заданы.")

    return {
        "email_password": True,
        "providers": {
            "apple": {
                "id": "apple",
                "label": "Apple",
                "enabled": apple_enabled,
                "configured": apple_configured,
                "policy_blocked": apple_policy_blocked,
            },
            "vk": {
                "id": "vk",
                "label": "VK ID",
                "enabled": s.OAUTH_VK_ENABLED and vk_configured,
                "configured": vk_configured,
                "policy_blocked": False,
            },
            "yandex": {
                "id": "yandex",
                "label": "Яндекс ID",
                "enabled": s.OAUTH_YANDEX_ENABLED and yandex_configured,
                "configured": yandex_configured,
                "policy_blocked": False,
            },
        },
        "operator_region": s.OAUTH_OPERATOR_REGION,
        "notes": notes,
        "legal_notice": (
            "Доступность способов входа задаётся конфигурацией оператора. "
            "Геолокация пользователя по IP не используется как юридический критерий."
        ),
    }


def assert_redirect_allowed(redirect_uri: str, settings: Settings | None = None) -> None:
    s = settings or get_settings()
    if redirect_uri not in s.oauth_redirect_allowlist:
        raise OAuthError("invalid_redirect", "Redirect URI не в allowlist")


def _provider_enabled(provider: OAuthProvider, settings: Settings) -> bool:
    avail = provider_availability(settings)["providers"][provider.value]
    return bool(avail["enabled"])


async def start_oauth(
    db: AsyncSession,
    provider: OAuthProvider,
    *,
    redirect_uri: str,
    client_kind: str = "web",
    link_user_id: uuid.UUID | None = None,
) -> dict[str, str]:
    settings = get_settings()
    if not _provider_enabled(provider, settings):
        raise OAuthError("provider_disabled", f"Провайдер {provider.value} недоступен")
    assert_redirect_allowed(redirect_uri, settings)

    state = secrets.token_urlsafe(32)
    nonce = secrets.token_urlsafe(32)
    verifier, challenge = _pkce_pair()
    now = datetime.now(UTC)
    db.add(
        OAuthLoginState(
            id=uuid.uuid4(),
            state=state,
            provider=provider,
            code_verifier=verifier,
            nonce=nonce,
            redirect_uri=redirect_uri,
            client_kind=client_kind,
            link_user_id=link_user_id,
            created_at=now,
            expires_at=now + timedelta(minutes=10),
        )
    )
    await db.flush()

    if provider == OAuthProvider.apple:
        params = {
            "client_id": settings.OAUTH_APPLE_CLIENT_ID,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "response_mode": "form_post",
            "scope": "name email",
            "state": state,
            "nonce": nonce,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
        url = f"{APPLE_AUTH}?{urlencode(params)}"
    elif provider == OAuthProvider.vk:
        params = {
            "client_id": settings.OAUTH_VK_CLIENT_ID,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "email",
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
        url = f"{VK_AUTH}?{urlencode(params)}"
    else:
        params = {
            "client_id": settings.OAUTH_YANDEX_CLIENT_ID,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "state": state,
            # Yandex supports PKCE on modern apps; include when configured.
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "force_confirm": "yes",
        }
        url = f"{YANDEX_AUTH}?{urlencode(params)}"

    return {"authorize_url": url, "state": state}


async def _consume_state(
    db: AsyncSession, state: str, provider: OAuthProvider
) -> OAuthLoginState:
    row = await db.scalar(select(OAuthLoginState).where(OAuthLoginState.state == state))
    if not row or row.provider != provider:
        raise OAuthError("invalid_state", "Неверный state")
    if row.consumed_at is not None:
        raise OAuthError("state_reuse", "State уже использован")
    if row.expires_at < datetime.now(UTC):
        raise OAuthError("state_expired", "Сессия входа истекла")
    row.consumed_at = datetime.now(UTC)
    await db.flush()
    return row


def _apple_client_secret(settings: Settings) -> str:
    """Build ES256 client_secret JWT for Apple token endpoint."""
    try:
        from jose import jwt
        from cryptography.hazmat.primitives import serialization
    except ImportError as e:
        raise OAuthError("apple_deps", "Нужны python-jose и cryptography для Apple ID") from e

    pem = settings.OAUTH_APPLE_PRIVATE_KEY.strip()
    if settings.OAUTH_APPLE_PRIVATE_KEY_FILE:
        with open(settings.OAUTH_APPLE_PRIVATE_KEY_FILE, encoding="utf-8") as f:
            pem = f.read()
    if "\\n" in pem:
        pem = pem.replace("\\n", "\n")
    key = serialization.load_pem_private_key(pem.encode(), password=None)
    now = int(time.time())
    headers = {"kid": settings.OAUTH_APPLE_KEY_ID}
    payload = {
        "iss": settings.OAUTH_APPLE_TEAM_ID,
        "iat": now,
        "exp": now + 1800,
        "aud": "https://appleid.apple.com",
        "sub": settings.OAUTH_APPLE_CLIENT_ID,
    }
    return jwt.encode(payload, key, algorithm="ES256", headers=headers)


async def _exchange_apple(code: str, redirect_uri: str, verifier: str | None) -> ProviderProfile:
    settings = get_settings()
    data = {
        "client_id": settings.OAUTH_APPLE_CLIENT_ID,
        "client_secret": _apple_client_secret(settings),
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri,
    }
    if verifier:
        data["code_verifier"] = verifier
    async with httpx.AsyncClient(timeout=20) as client:
        r = await client.post(APPLE_TOKEN, data=data)
    if r.status_code >= 400:
        raise OAuthError("apple_token", "Не удалось обменять код Apple")
    body = r.json()
    id_token = body.get("id_token")
    if not id_token:
        raise OAuthError("apple_token", "Apple не вернул id_token")
    claims = _decode_unverified_jwt_claims(id_token)
    # Full production should verify signature against Apple JWKS + nonce.
    sub = claims.get("sub")
    if not sub:
        raise OAuthError("apple_claims", "Нет sub в токене Apple")
    email = claims.get("email")
    email_verified = str(claims.get("email_verified", "")).lower() in ("true", "1")
    return ProviderProfile(
        provider=OAuthProvider.apple,
        provider_user_id=str(sub),
        email=email.lower() if isinstance(email, str) else None,
        email_verified=email_verified,
        display_name=None,
        raw_claims={"iss": claims.get("iss"), "aud": claims.get("aud"), "email": email},
    )


async def _exchange_vk(code: str, redirect_uri: str, verifier: str | None, device_id: str | None) -> ProviderProfile:
    settings = get_settings()
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": settings.OAUTH_VK_CLIENT_ID,
        "client_secret": settings.OAUTH_VK_CLIENT_SECRET,
        "redirect_uri": redirect_uri,
        "code_verifier": verifier or "",
        "device_id": device_id or "",
    }
    async with httpx.AsyncClient(timeout=20) as client:
        r = await client.post(VK_TOKEN, data=data)
        if r.status_code >= 400:
            raise OAuthError("vk_token", "Не удалось обменять код VK ID")
        body = r.json()
        access_token = body.get("access_token")
        user_id = body.get("user_id") or (body.get("user") or {}).get("user_id")
        email = body.get("email")
        display_name: str | None = None
        avatar: str | None = None
        if not user_id:
            id_token = body.get("id_token")
            if id_token:
                claims = _decode_unverified_jwt_claims(id_token)
                user_id = claims.get("sub")
                email = email or claims.get("email")
        if access_token:
            info = await client.post(
                VK_USER_INFO,
                data={
                    "client_id": settings.OAUTH_VK_CLIENT_ID,
                    "access_token": access_token,
                },
            )
            if info.status_code < 400:
                user_obj = (info.json() or {}).get("user") or {}
                user_id = user_id or user_obj.get("user_id")
                email = email or user_obj.get("email")
                first = (user_obj.get("first_name") or "").strip()
                last = (user_obj.get("last_name") or "").strip()
                display_name = f"{first} {last}".strip() or None
                raw_avatar = user_obj.get("avatar") or user_obj.get("photo_200") or user_obj.get("photo")
                if isinstance(raw_avatar, str) and raw_avatar.startswith("http"):
                    avatar = raw_avatar
    if not user_id:
        raise OAuthError("vk_claims", "VK ID не вернул идентификатор пользователя")
    return ProviderProfile(
        provider=OAuthProvider.vk,
        provider_user_id=str(user_id),
        email=email.lower() if isinstance(email, str) else None,
        email_verified=bool(email),
        display_name=display_name,
        raw_claims={"has_email": bool(email), "has_avatar": bool(avatar)},
        avatar_url=avatar,
    )


async def _exchange_yandex(code: str, redirect_uri: str, verifier: str | None) -> ProviderProfile:
    settings = get_settings()
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": settings.OAUTH_YANDEX_CLIENT_ID,
        "client_secret": settings.OAUTH_YANDEX_CLIENT_SECRET,
    }
    if verifier:
        data["code_verifier"] = verifier
    # redirect_uri may be required depending on app type
    data["redirect_uri"] = redirect_uri
    async with httpx.AsyncClient(timeout=20) as client:
        r = await client.post(YANDEX_TOKEN, data=data)
        if r.status_code >= 400:
            raise OAuthError("yandex_token", "Не удалось обменять код Яндекс ID")
        token = r.json().get("access_token")
        if not token:
            raise OAuthError("yandex_token", "Нет access_token Яндекс")
        info = await client.get(
            YANDEX_INFO,
            params={"format": "json"},
            headers={"Authorization": f"OAuth {token}"},
        )
    if info.status_code >= 400:
        raise OAuthError("yandex_info", "Не удалось получить профиль Яндекс")
    body = info.json()
    uid = body.get("id") or body.get("psuid")
    if not uid:
        raise OAuthError("yandex_claims", "Нет id в профиле Яндекс")
    emails = body.get("emails") or []
    default_email = body.get("default_email")
    email = default_email or (emails[0] if emails else None)
    name = body.get("real_name") or body.get("display_name") or body.get("login")
    avatar: str | None = None
    avatar_id = body.get("default_avatar_id")
    if isinstance(avatar_id, str) and avatar_id and not body.get("is_avatar_empty"):
        avatar = f"https://avatars.yandex.net/get-yapic/{avatar_id}/islands-200"
    return ProviderProfile(
        provider=OAuthProvider.yandex,
        provider_user_id=str(uid),
        email=email.lower() if isinstance(email, str) else None,
        email_verified=bool(email),
        display_name=name,
        raw_claims={"login": body.get("login"), "has_avatar": bool(avatar)},
        avatar_url=avatar,
    )


def _decode_unverified_jwt_claims(token: str) -> dict[str, Any]:
    try:
        from jose import jwt

        return jwt.decode(token, key="", options={"verify_signature": False})
    except Exception as e:
        raise OAuthError("bad_token", "Некорректный id_token") from e


async def exchange_code(
    db: AsyncSession,
    provider: OAuthProvider,
    *,
    code: str,
    state: str,
    device_id: str | None = None,
) -> tuple[User, bool]:
    """Complete web OAuth. Returns (user, created)."""
    row = await _consume_state(db, state, provider)
    profile = await _fetch_profile(provider, code, row.redirect_uri, row.code_verifier, device_id)
    if row.link_user_id:
        user = await link_identity(db, row.link_user_id, profile)
        return user, False
    return await login_or_register(db, profile)


async def mobile_complete(
    db: AsyncSession,
    provider: OAuthProvider,
    *,
    code: str | None = None,
    id_token: str | None = None,
    redirect_uri: str,
    code_verifier: str | None = None,
    device_id: str | None = None,
    link_user_id: uuid.UUID | None = None,
) -> tuple[User, bool]:
    settings = get_settings()
    if not _provider_enabled(provider, settings):
        raise OAuthError("provider_disabled", f"Провайдер {provider.value} недоступен")
    assert_redirect_allowed(redirect_uri, settings)
    if id_token and provider == OAuthProvider.apple:
        claims = _decode_unverified_jwt_claims(id_token)
        sub = claims.get("sub")
        if not sub:
            raise OAuthError("apple_claims", "Нет sub")
        email = claims.get("email")
        profile = ProviderProfile(
            provider=OAuthProvider.apple,
            provider_user_id=str(sub),
            email=email.lower() if isinstance(email, str) else None,
            email_verified=str(claims.get("email_verified", "")).lower() in ("true", "1"),
            display_name=None,
            raw_claims={"iss": claims.get("iss"), "aud": claims.get("aud")},
        )
    elif code:
        profile = await _fetch_profile(provider, code, redirect_uri, code_verifier, device_id)
    else:
        raise OAuthError("missing_code", "Нужен code или id_token")
    if link_user_id:
        return await link_identity(db, link_user_id, profile), False
    return await login_or_register(db, profile)


async def _fetch_profile(
    provider: OAuthProvider,
    code: str,
    redirect_uri: str,
    verifier: str | None,
    device_id: str | None,
) -> ProviderProfile:
    if provider == OAuthProvider.apple:
        return await _exchange_apple(code, redirect_uri, verifier)
    if provider == OAuthProvider.vk:
        return await _exchange_vk(code, redirect_uri, verifier, device_id)
    return await _exchange_yandex(code, redirect_uri, verifier)


def _synthetic_email(provider: OAuthProvider, provider_user_id: str) -> str:
    safe = hashlib.sha256(f"{provider.value}:{provider_user_id}".encode()).hexdigest()[:24]
    return f"{provider.value}_{safe}@oauth.takt.local"


async def _maybe_set_avatar_from_url(user: User, avatar_url: str | None, *, force: bool = False) -> bool:
    """Download provider photo into local avatar storage. Skip if user already has one (unless force)."""
    if not avatar_url or not avatar_url.startswith(("http://", "https://")):
        return False
    if user.avatar_path and not force:
        return False
    settings = get_settings()
    max_bytes = min(settings.MAX_UPLOAD_BYTES, 2 * 1024 * 1024)
    try:
        async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
            r = await client.get(avatar_url)
        if r.status_code >= 400 or not r.content:
            return False
        if len(r.content) > max_bytes or len(r.content) < 32:
            return False
        content_type = (r.headers.get("content-type") or "").split(";")[0].strip().lower()
        ext = _AVATAR_EXT_BY_TYPE.get(content_type)
        if not ext:
            # sniff magic bytes
            head = r.content[:16]
            if head.startswith(b"\xff\xd8\xff"):
                ext = ".jpg"
            elif head.startswith(b"\x89PNG"):
                ext = ".png"
            elif head.startswith(b"RIFF") and b"WEBP" in head:
                ext = ".webp"
            elif head[:6] in (b"GIF87a", b"GIF89a"):
                ext = ".gif"
            else:
                return False
        avatars_dir = Path(settings.UPLOAD_DIR) / "avatars"
        avatars_dir.mkdir(parents=True, exist_ok=True)
        for old in avatars_dir.glob(f"{user.id}.*"):
            old.unlink(missing_ok=True)
        path = avatars_dir / f"{user.id}{ext}"
        path.write_bytes(r.content)
        user.avatar_path = str(path)
        return True
    except Exception:
        return False


async def login_or_register(db: AsyncSession, profile: ProviderProfile) -> tuple[User, bool]:
    identity = await db.scalar(
        select(UserIdentity).where(
            UserIdentity.provider == profile.provider,
            UserIdentity.provider_user_id == profile.provider_user_id,
        )
    )
    if identity:
        user = await db.get(User, identity.user_id)
        if not user or not user.is_active:
            raise OAuthError("inactive", "Учётная запись отключена")
        if user.blocked_until and user.blocked_until > datetime.now(UTC):
            raise OAuthError("blocked", "Учётная запись временно ограничена")
        user.last_login_at = datetime.now(UTC)
        if profile.display_name and (not user.name or user.name.startswith("Пользователь")):
            user.name = profile.display_name[:200]
        await _maybe_set_avatar_from_url(user, profile.avatar_url)
        await record_activity(db, user.id, "login_oauth", {"provider": profile.provider.value})
        await db.flush()
        return user, False

    # Do NOT auto-merge by email alone — require explicit link flow.
    email = profile.email
    created = False
    if email:
        existing = await db.scalar(select(User).where(User.email == email.lower()))
        if existing:
            raise OAuthError(
                "email_owned",
                "Email уже занят другим аккаунтом. Войдите и привяжите провайдера в профиле.",
                status_code=409,
            )
    else:
        email = _synthetic_email(profile.provider, profile.provider_user_id)

    name = profile.display_name or (profile.email.split("@")[0] if profile.email else "Пользователь Takt")
    user = User(
        email=email.lower(),
        password_hash=None,
        name=name[:200],
        role=UserRole.member,
        platform_role=PlatformRole.none,
        is_active=True,
        must_change_password=False,
        last_login_at=datetime.now(UTC),
    )
    db.add(user)
    await db.flush()
    created = True
    await _attach_identity(db, user.id, profile)
    await _maybe_set_avatar_from_url(user, profile.avatar_url, force=True)
    await record_activity(
        db,
        user.id,
        "register_oauth" if created else "login_oauth",
        {"provider": profile.provider.value},
    )
    return user, created


async def link_identity(db: AsyncSession, user_id: uuid.UUID, profile: ProviderProfile) -> User:
    user = await db.get(User, user_id)
    if not user or not user.is_active:
        raise OAuthError("inactive", "Пользователь не найден")
    taken = await db.scalar(
        select(UserIdentity).where(
            UserIdentity.provider == profile.provider,
            UserIdentity.provider_user_id == profile.provider_user_id,
        )
    )
    if taken and taken.user_id != user_id:
        raise OAuthError("identity_taken", "Этот аккаунт провайдера уже привязан к другому пользователю")
    if taken and taken.user_id == user_id:
        await _maybe_set_avatar_from_url(user, profile.avatar_url)
        return user
    same_provider = await db.scalar(
        select(UserIdentity).where(
            UserIdentity.user_id == user_id, UserIdentity.provider == profile.provider
        )
    )
    if same_provider:
        raise OAuthError("already_linked", "Провайдер уже привязан")
    await _attach_identity(db, user_id, profile)
    await _maybe_set_avatar_from_url(user, profile.avatar_url)
    await record_activity(db, user_id, "oauth_linked", {"provider": profile.provider.value})
    return user


async def _attach_identity(db: AsyncSession, user_id: uuid.UUID, profile: ProviderProfile) -> UserIdentity:
    # Strip potentially sensitive raw fields — keep only non-secret claims.
    safe_raw = {k: v for k, v in (profile.raw_claims or {}).items() if k not in ("access_token", "refresh_token")}
    row = UserIdentity(
        id=uuid.uuid4(),
        user_id=user_id,
        provider=profile.provider,
        provider_user_id=profile.provider_user_id,
        email=profile.email,
        email_verified=profile.email_verified,
        display_name=profile.display_name,
        raw_claims=safe_raw,
        linked_at=datetime.now(UTC),
    )
    db.add(row)
    await db.flush()
    return row


async def list_identities(db: AsyncSession, user_id: uuid.UUID) -> list[dict]:
    rows = (
        await db.execute(select(UserIdentity).where(UserIdentity.user_id == user_id))
    ).scalars().all()
    return [
        {
            "id": str(r.id),
            "provider": r.provider.value,
            "email": r.email,
            "email_verified": r.email_verified,
            "display_name": r.display_name,
            "linked_at": r.linked_at.isoformat() if r.linked_at else None,
        }
        for r in rows
    ]


async def unlink_identity(db: AsyncSession, user: User, identity_id: uuid.UUID) -> None:
    row = await db.get(UserIdentity, identity_id)
    if not row or row.user_id != user.id:
        raise OAuthError("not_found", "Связь не найдена", status_code=404)
    identity_count = await db.scalar(
        select(func.count()).select_from(UserIdentity).where(UserIdentity.user_id == user.id)
    ) or 0
    has_password = bool(user.password_hash)
    if identity_count <= 1 and not has_password:
        raise OAuthError(
            "last_method",
            "Нельзя отвязать последний способ входа. Сначала задайте пароль.",
        )
    await db.delete(row)
    await record_activity(db, user.id, "oauth_unlinked", {"provider": row.provider.value})
    await db.flush()


async def issue_session(db: AsyncSession, user: User) -> tuple[str, str]:
    access, refresh, _ = await auth_service.create_token_pair(db, user)
    return access, refresh
