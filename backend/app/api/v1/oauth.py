"""OAuth start/callback + identity link/unlink. Secrets stay on the server."""

from __future__ import annotations

import uuid
from typing import Annotated, Literal
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request, Response
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional, verify_csrf
from app.api.v1.auth import _set_auth_cookies, _user_public
from app.core.config import get_settings
from app.core.limiter import limiter
from app.db.session import get_db
from app.models.platform import OAuthProvider
from app.models.user import User
from app.services import oauth_service
from app.services.activity_service import record_activity

router = APIRouter(prefix="/auth/oauth", tags=["oauth"])


def _oauth_http(e: oauth_service.OAuthError) -> HTTPException:
    return HTTPException(
        status_code=e.status_code,
        detail={"error": {"code": e.code, "message": e.message}},
    )


@router.get("/providers")
async def list_providers(db: Annotated[AsyncSession, Depends(get_db)]):
    return await oauth_service.provider_availability(db)


@router.get("/{provider}/start")
@limiter.limit("20/minute")
async def oauth_start(
    request: Request,
    provider: Literal["apple", "vk", "yandex"],
    db: Annotated[AsyncSession, Depends(get_db)],
    redirect_uri: str | None = None,
    client: Literal["web", "mobile"] = "web",
    link: bool = False,
    user: Annotated[User | None, Depends(get_current_user_optional)] = None,
):
    settings = get_settings()
    uri = redirect_uri or (
        settings.OAUTH_MOBILE_REDIRECT_URI if client == "mobile" else settings.OAUTH_WEB_REDIRECT_URI
    )
    link_user_id = user.id if link and user else None
    if link and not user:
        raise HTTPException(
            status_code=401,
            detail={"error": {"code": "unauthorized", "message": "Войдите, чтобы привязать аккаунт"}},
        )
    try:
        started = await oauth_service.start_oauth(
            db,
            OAuthProvider(provider),
            redirect_uri=uri,
            client_kind=client,
            link_user_id=link_user_id,
        )
        await db.commit()
    except oauth_service.OAuthError as e:
        raise _oauth_http(e)
    return started


async def _finish_web(
    db: AsyncSession,
    response: Response,
    provider: OAuthProvider,
    code: str,
    state: str,
    device_id: str | None = None,
) -> RedirectResponse:
    settings = get_settings()
    try:
        user, created = await oauth_service.exchange_code(
            db, provider, code=code, state=state, device_id=device_id
        )
        access, refresh = await oauth_service.issue_session(db, user)
        await record_activity(db, user.id, "login_oauth", {"provider": provider.value, "created": created})
        await db.commit()
    except oauth_service.OAuthError as e:
        await db.rollback()
        q = urlencode({"oauth_error": e.code, "message": e.message})
        return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)

    # Temporary response to set cookies, then redirect
    redirect = RedirectResponse(f"{settings.APP_PUBLIC_URL}/app/projects", status_code=302)
    _set_auth_cookies(redirect, access, refresh)
    return redirect


@router.get("/callback")
@limiter.limit("30/minute")
async def oauth_callback_get(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    response: Response,
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
    provider: Literal["apple", "vk", "yandex"] | None = Query(default=None),
):
    settings = get_settings()
    if error:
        q = urlencode({"oauth_error": error})
        return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)
    if not code or not state or not provider:
        q = urlencode({"oauth_error": "missing_params"})
        return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)
    return await _finish_web(db, response, OAuthProvider(provider), code, state)


@router.post("/callback")
@limiter.limit("30/minute")
async def oauth_callback_post(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    response: Response,
    code: Annotated[str | None, Form()] = None,
    state: Annotated[str | None, Form()] = None,
    error: Annotated[str | None, Form()] = None,
    user: Annotated[str | None, Form()] = None,  # Apple may send user JSON once
    id_token: Annotated[str | None, Form()] = None,
):
    """Apple uses form_post. Provider inferred from state row."""
    settings = get_settings()
    if error:
        q = urlencode({"oauth_error": str(error)})
        return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)
    if not code or not state:
        q = urlencode({"oauth_error": "missing_params"})
        return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)
    from sqlalchemy import select
    from app.models.platform import OAuthLoginState

    row = await db.scalar(select(OAuthLoginState).where(OAuthLoginState.state == state))
    if not row:
        q = urlencode({"oauth_error": "invalid_state"})
        return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)
    return await _finish_web(db, response, row.provider, code, state)


class MobileOAuthBody(BaseModel):
    provider: Literal["apple", "vk", "yandex"]
    code: str | None = None
    id_token: str | None = None
    redirect_uri: str
    code_verifier: str | None = None
    device_id: str | None = None
    link: bool = False


@router.post("/mobile")
@limiter.limit("20/minute")
async def oauth_mobile(
    request: Request,
    body: MobileOAuthBody,
    db: Annotated[AsyncSession, Depends(get_db)],
    response: Response,
    user: Annotated[User | None, Depends(get_current_user_optional)] = None,
):
    try:
        u, created = await oauth_service.mobile_complete(
            db,
            OAuthProvider(body.provider),
            code=body.code,
            id_token=body.id_token,
            redirect_uri=body.redirect_uri,
            code_verifier=body.code_verifier,
            device_id=body.device_id,
            link_user_id=user.id if body.link and user else None,
        )
        access, refresh = await oauth_service.issue_session(db, u)
        await record_activity(db, u.id, "login_oauth", {"provider": body.provider, "mobile": True})
        await db.commit()
    except oauth_service.OAuthError as e:
        raise _oauth_http(e)

    # Mobile prefers tokens in JSON; also set cookies for hybrid webviews.
    _set_auth_cookies(response, access, refresh)
    return {
        "user": _user_public(u),
        "access_token": access,
        "refresh_token": refresh,
        "created": created,
    }


@router.get("/identities")
async def my_identities(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    return {"items": await oauth_service.list_identities(db, user.id), "has_password": bool(user.password_hash)}


@router.delete("/identities/{identity_id}", dependencies=[Depends(verify_csrf)])
async def unlink(
    identity_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await oauth_service.unlink_identity(db, user, identity_id)
        await db.commit()
    except oauth_service.OAuthError as e:
        raise _oauth_http(e)
    return {"ok": True}
