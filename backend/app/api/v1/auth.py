from typing import Annotated

from fastapi import APIRouter, Cookie, Depends, HTTPException, Request, Response, status
from app.core.limiter import limiter
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ACCESS_COOKIE, REFRESH_COOKIE, get_current_user, verify_csrf
from app.api.serializers import avatar_url
from app.core.config import get_settings
from app.core.csrf import CSRF_COOKIE, generate_csrf_token
from app.core.security import decode_token, hash_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    ChangePasswordRequest,
    ForceChangePasswordRequest,
    LoginRequest,
    UserPublic,
)
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


def _set_auth_cookies(response: Response, access: str, refresh: str) -> None:
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
    response.set_cookie(
        CSRF_COOKIE,
        csrf,
        max_age=86400 * 7,
        httponly=False,
        secure=settings.COOKIE_SECURE,
        samesite="lax",
        path="/",
    )


def _user_public(user: User) -> UserPublic:
    return UserPublic(
        id=str(user.id),
        email=user.email,
        name=user.name,
        role=user.role.value,
        avatar_url=avatar_url(user),
        must_change_password=user.must_change_password,
    )


@router.post("/login")
@limiter.limit(get_settings().LOGIN_RATE_LIMIT)  # noqa: B008
async def login(
    request: Request,
    body: LoginRequest,
    response: Response,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    settings = get_settings()
    ip = request.client.host if request.client else None
    try:
        user = await auth_service.authenticate_user(
            db,
            body.email,
            body.password,
            ip,
            settings.LOGIN_LOCKOUT_ATTEMPTS,
            settings.LOGIN_LOCKOUT_MINUTES,
        )
    except auth_service.AuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": e.code, "message": e.message}},
        )
    access, refresh, _ = await auth_service.create_token_pair(db, user)
    await db.commit()
    _set_auth_cookies(response, access, refresh)
    return {"user": _user_public(user)}


@router.post("/logout", dependencies=[Depends(verify_csrf)])
async def logout(
    response: Response,
    db: Annotated[AsyncSession, Depends(get_db)],
    refresh_token: Annotated[str | None, Cookie(alias=REFRESH_COOKIE)] = None,
):
    if refresh_token:
        payload = decode_token(refresh_token)
        if payload and payload.get("jti"):
            await auth_service.revoke_refresh_token(db, payload["jti"])
            await db.commit()
    response.delete_cookie(ACCESS_COOKIE, path="/")
    response.delete_cookie(REFRESH_COOKIE, path="/")
    response.delete_cookie(CSRF_COOKIE, path="/")
    return {"ok": True}


@router.get("/me")
async def me(user: Annotated[User, Depends(get_current_user)]):
    return {"user": _user_public(user)}


@router.post("/refresh")
async def refresh(
    response: Response,
    db: Annotated[AsyncSession, Depends(get_db)],
    refresh_token: Annotated[str | None, Cookie(alias=REFRESH_COOKIE)] = None,
):
    if not refresh_token:
        raise HTTPException(
            status_code=401,
            detail={"error": {"code": "no_refresh", "message": "Нет сессии"}},
        )
    try:
        access, new_refresh, user = await auth_service.refresh_session(db, refresh_token)
    except auth_service.AuthError as e:
        raise HTTPException(status_code=401, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    _set_auth_cookies(response, access, new_refresh)
    return {"user": _user_public(user)}


@router.post("/change-password", dependencies=[Depends(verify_csrf)])
async def change_password(
    body: ChangePasswordRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    response: Response,
):
    try:
        await auth_service.change_password(db, user, body.current_password, body.new_password)
    except auth_service.AuthError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    response.delete_cookie(ACCESS_COOKIE, path="/")
    response.delete_cookie(REFRESH_COOKIE, path="/")
    return {"ok": True}


@router.post("/force-change-password", dependencies=[Depends(verify_csrf)])
async def force_change_password(
    body: ForceChangePasswordRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if not user.must_change_password:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "not_required", "message": "Смена пароля не требуется"}},
        )
    user.password_hash = hash_password(body.new_password)
    user.must_change_password = False
    await auth_service.revoke_all_user_tokens(db, user.id)
    await db.commit()
    return {"ok": True}
