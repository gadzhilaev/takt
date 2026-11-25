"""Shared helpers for web auth cookies and public user payload (used by auth + oauth)."""

import uuid

from fastapi import Request, Response

from app.api.deps import ACCESS_COOKIE, REFRESH_COOKIE, effective_platform_role
from app.api.serializers import avatar_url
from app.core.config import get_settings
from app.core.csrf import CSRF_COOKIE, generate_csrf_token
from app.models.user import User
from app.schemas.auth import UserPublic

DEVICE_ID_COOKIE = "takt_device_id"


def resolve_device_session_id(request: Request) -> uuid.UUID:
    """Use a stable per-installation/browser ID so repeat sign-ins group together."""
    raw = request.headers.get("x-client-device-id") or request.cookies.get(DEVICE_ID_COOKIE)
    try:
        return uuid.UUID(raw) if raw else uuid.uuid4()
    except (ValueError, TypeError):
        return uuid.uuid4()


def set_device_id_cookie(response: Response, session_id: uuid.UUID) -> None:
    settings = get_settings()
    options: dict = {
        "httponly": True,
        "secure": settings.COOKIE_SECURE,
        "samesite": "lax",
        "path": "/",
        "max_age": 365 * 24 * 60 * 60,
    }
    if settings.COOKIE_DOMAIN:
        options["domain"] = settings.COOKIE_DOMAIN
    response.set_cookie(DEVICE_ID_COOKIE, str(session_id), **options)


def set_auth_cookies(response: Response, access: str, refresh: str) -> None:
    settings = get_settings()
    common: dict = {
        "httponly": True,
        "secure": settings.COOKIE_SECURE,
        "samesite": "lax",
        "path": "/",
    }
    if settings.COOKIE_DOMAIN:
        common["domain"] = settings.COOKIE_DOMAIN
    response.set_cookie(
        ACCESS_COOKIE,
        access,
        max_age=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        **common,
    )
    response.set_cookie(
        REFRESH_COOKIE,
        refresh,
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        **common,
    )
    csrf = generate_csrf_token()
    csrf_opts: dict = {
        # Align with refresh so long-lived sessions keep mutating requests working.
        "max_age": settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        "httponly": False,
        "secure": settings.COOKIE_SECURE,
        "samesite": "lax",
        "path": "/",
    }
    if settings.COOKIE_DOMAIN:
        csrf_opts["domain"] = settings.COOKIE_DOMAIN
    response.set_cookie(CSRF_COOKIE, csrf, **csrf_opts)


def user_public(user: User) -> UserPublic:
    return UserPublic(
        id=str(user.id),
        email=user.email,
        name=user.name,
        role=user.role.value,
        platform_role=effective_platform_role(user).value,
        avatar_url=avatar_url(user),
        must_change_password=user.must_change_password,
    )
