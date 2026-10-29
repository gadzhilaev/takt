import uuid
from typing import Annotated

from fastapi import Cookie, Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.csrf import CSRF_HEADER, validate_csrf_token
from app.core.security import decode_token
from app.db.session import get_db
from app.models.user import PLATFORM_ROLE_RANK, PlatformRole, User, UserRole

ACCESS_COOKIE = "access_token"
REFRESH_COOKIE = "refresh_token"


def effective_platform_role(user: User) -> PlatformRole:
    """Legacy UserRole.admin maps to at least platform admin."""
    role = user.platform_role or PlatformRole.none
    if user.role == UserRole.admin and PLATFORM_ROLE_RANK[role] < PLATFORM_ROLE_RANK[PlatformRole.admin]:
        return PlatformRole.super_admin if role == PlatformRole.none else role
    return role


def has_platform_role(user: User, minimum: PlatformRole) -> bool:
    return PLATFORM_ROLE_RANK[effective_platform_role(user)] >= PLATFORM_ROLE_RANK[minimum]


def _token_from_auth_header(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        return None
    return parts[1].strip()


async def get_current_user_optional(
    db: Annotated[AsyncSession, Depends(get_db)],
    access_token: Annotated[str | None, Cookie(alias=ACCESS_COOKIE)] = None,
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> User | None:
    raw = access_token or _token_from_auth_header(authorization)
    if not raw:
        return None
    payload = decode_token(raw)
    if not payload or payload.get("type") != "access":
        return None
    try:
        user_id = uuid.UUID(payload["sub"])
    except (KeyError, ValueError):
        return None
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        return None
    return user


async def get_current_user(
    user: Annotated[User | None, Depends(get_current_user_optional)],
) -> User:
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "unauthorized", "message": "Требуется вход"}},
        )
    return user


async def require_admin(user: Annotated[User, Depends(get_current_user)]) -> User:
    """Legacy team admin API — UserRole.admin or platform admin+."""
    if user.role != UserRole.admin and not has_platform_role(user, PlatformRole.admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "forbidden", "message": "Доступ только для администратора"}},
        )
    return user


def require_platform_role(minimum: PlatformRole):
    async def _dep(user: Annotated[User, Depends(get_current_user)]) -> User:
        if not has_platform_role(user, minimum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "forbidden",
                        "message": "Недостаточно прав платформенного администратора",
                    }
                },
            )
        return user

    return _dep


async def require_platform_admin(user: Annotated[User, Depends(get_current_user)]) -> User:
    if not has_platform_role(user, PlatformRole.admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "forbidden", "message": "Требуется platform admin"}},
        )
    return user


async def require_platform_moderator(user: Annotated[User, Depends(get_current_user)]) -> User:
    if not has_platform_role(user, PlatformRole.moderator):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "forbidden", "message": "Требуется platform moderator"}},
        )
    return user


async def require_super_admin(user: Annotated[User, Depends(get_current_user)]) -> User:
    if not has_platform_role(user, PlatformRole.super_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "forbidden", "message": "Требуется super_admin"}},
        )
    return user


async def verify_csrf(
    request: Request,
    csrf_header: Annotated[str | None, Header(alias=CSRF_HEADER)] = None,
    csrf_cookie: Annotated[str | None, Cookie(alias="csrf_token")] = None,
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> None:
    if request.method in ("GET", "HEAD", "OPTIONS"):
        return
    settings = get_settings()
    if settings.ENV == "test":
        return
    # Mobile / API clients authenticate with Bearer JWT — CSRF does not apply.
    if _token_from_auth_header(authorization):
        return
    if not validate_csrf_token(csrf_header or "", csrf_cookie):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "csrf_invalid", "message": "Недействительный CSRF-токен"}},
        )
