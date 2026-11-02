"""OAuth start/callback + identity link/unlink. Secrets stay on the server."""

from __future__ import annotations

import html
import json
import uuid
from typing import Annotated, Literal
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request, Response
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth_cookies import set_auth_cookies, user_public
from app.api.deps import get_current_user, get_current_user_optional, verify_csrf
from app.core.config import get_settings
from app.core.limiter import limiter
from app.db.session import get_db
from app.models.platform import OAuthLoginState, OAuthProvider
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
    next: str | None = Query(default=None, alias="next"),
    user: Annotated[User | None, Depends(get_current_user_optional)] = None,
):
    settings = get_settings()
    # VK/Yandex consoles only allow HTTPS callbacks. Mobile always uses HTTPS;
    # /callback then bounces to takt:// for ASWebAuthenticationSession.
    # Ignore client-supplied takt:// and legacy OAUTH_MOBILE_REDIRECT_URI custom schemes.
    if client == "mobile":
        mobile = (settings.OAUTH_MOBILE_REDIRECT_URI or "").strip()
        if mobile.startswith(("https://", "http://")):
            uri = mobile
        else:
            uri = settings.OAUTH_WEB_REDIRECT_URI
    else:
        uri = redirect_uri or settings.OAUTH_WEB_REDIRECT_URI
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
            return_path=next,
        )
        await db.commit()
    except oauth_service.OAuthError as e:
        raise _oauth_http(e)
    return started


_OAUTH_ERROR_RU: dict[str, str] = {
    "missing_params": "Не удалось завершить вход: нет кода подтверждения. Попробуйте ещё раз.",
    "invalid_state": "Сессия входа устарела. Начните вход заново.",
    "state_expired": "Сессия входа истекла. Начните вход заново.",
    "state_reuse": "Этот вход уже был использован. Начните заново.",
    "provider_disabled": "Этот способ входа сейчас недоступен.",
    "access_denied": "Вход отменён.",
    "email_owned": "Email уже занят. Войдите в существующий аккаунт и привяжите провайдера в профиле.",
    "vk_token": "Не удалось войти через VK ID. Попробуйте ещё раз.",
    "yandex_token": "Не удалось войти через Яндекс ID. Попробуйте ещё раз.",
    "apple_token": "Не удалось войти через Apple. Попробуйте ещё раз.",
}


def _login_error_redirect(settings, *, code: str, message: str | None = None) -> RedirectResponse:
    text = (message or "").strip() or _OAUTH_ERROR_RU.get(code) or "Не удалось выполнить вход. Попробуйте ещё раз."
    q = urlencode({"oauth_error": code, "message": text})
    return RedirectResponse(f"{settings.APP_PUBLIC_URL}/login?{q}", status_code=302)


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
        user, created, return_path = await oauth_service.exchange_code(
            db, provider, code=code, state=state, device_id=device_id
        )
        access, refresh = await oauth_service.issue_session(db, user)
        await record_activity(db, user.id, "login_oauth", {"provider": provider.value, "created": created})
        await db.commit()
    except oauth_service.OAuthError as e:
        await db.rollback()
        return _login_error_redirect(settings, code=e.code, message=e.message)

    # Keep invite/next path; membership only after explicit «Принять приглашение».
    dest = return_path or "/app/projects"
    redirect = RedirectResponse(f"{settings.APP_PUBLIC_URL}{dest}", status_code=302)
    set_auth_cookies(redirect, access, refresh)
    return redirect


async def _oauth_state_row(db: AsyncSession, state: str) -> OAuthLoginState | None:
    from sqlalchemy import select

    return await db.scalar(select(OAuthLoginState).where(OAuthLoginState.state == state))


async def _provider_from_state(db: AsyncSession, state: str) -> OAuthProvider | None:
    row = await _oauth_state_row(db, state)
    return row.provider if row else None


def _mobile_deep_link_bounce(**params: str | None) -> HTMLResponse:
    """Hand code/error back to the app without consuming PKCE state (POST /mobile does that)."""
    settings = get_settings()
    clean = {k: v for k, v in params.items() if v}
    base = settings.OAUTH_MOBILE_DEEP_LINK.rstrip("?")
    target = f"{base}?{urlencode(clean)}" if clean else base
    safe_href = html.escape(target, quote=True)
    safe_js = json.dumps(target)
    body = f"""<!DOCTYPE html>
<html lang="ru"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<meta http-equiv="refresh" content="0;url={safe_href}"/>
<title>Takt</title>
<script>window.location.replace({safe_js});</script>
</head><body>
<p>Возвращаем в приложение…</p>
<p><a href="{safe_href}">Открыть Takt</a></p>
</body></html>"""
    return HTMLResponse(content=body, headers={"Cache-Control": "no-store"})


@router.get("/callback")
@limiter.limit("30/minute")
async def oauth_callback_get(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    response: Response,
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
    device_id: str | None = None,
    provider: Literal["apple", "vk", "yandex"] | None = Query(default=None),
):
    """VK / Yandex redirect here with code+state (no provider query). Resolve provider from state."""
    settings = get_settings()
    row = await _oauth_state_row(db, state) if state else None
    if row and row.client_kind == "mobile":
        if error:
            return _mobile_deep_link_bounce(
                error=str(error),
                message=_OAUTH_ERROR_RU.get(str(error)) or str(error),
                state=state,
            )
        if not code or not state:
            return _mobile_deep_link_bounce(
                error="missing_params",
                message=_OAUTH_ERROR_RU["missing_params"],
                state=state,
            )
        return _mobile_deep_link_bounce(code=code, state=state, device_id=device_id)

    if error:
        return _login_error_redirect(settings, code=str(error), message=_OAUTH_ERROR_RU.get(str(error)))
    if not code or not state:
        return _login_error_redirect(settings, code="missing_params")
    resolved = OAuthProvider(provider) if provider else (row.provider if row else None)
    if not resolved:
        return _login_error_redirect(settings, code="invalid_state")
    return await _finish_web(db, response, resolved, code, state, device_id=device_id)


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
    device_id: Annotated[str | None, Form()] = None,
):
    """Apple uses form_post. Provider inferred from state row."""
    settings = get_settings()
    if error:
        return _login_error_redirect(settings, code=str(error), message=_OAUTH_ERROR_RU.get(str(error)))
    if not code or not state:
        return _login_error_redirect(settings, code="missing_params")
    resolved = await _provider_from_state(db, state)
    if not resolved:
        return _login_error_redirect(settings, code="invalid_state")
    return await _finish_web(db, response, resolved, code, state, device_id=device_id)


class MobileOAuthBody(BaseModel):
    provider: Literal["apple", "vk", "yandex"]
    code: str | None = None
    id_token: str | None = None
    redirect_uri: str
    code_verifier: str | None = None
    device_id: str | None = None
    state: str | None = None
    display_name: str | None = None
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
        u, created, _return_path = await oauth_service.mobile_complete(
            db,
            OAuthProvider(body.provider),
            code=body.code,
            id_token=body.id_token,
            redirect_uri=body.redirect_uri,
            code_verifier=body.code_verifier,
            device_id=body.device_id,
            state=body.state,
            display_name=body.display_name,
            link_user_id=user.id if body.link and user else None,
        )
        access, refresh = await oauth_service.issue_session(db, u)
        await record_activity(db, u.id, "login_oauth", {"provider": body.provider, "mobile": True})
        await db.commit()
    except oauth_service.OAuthError as e:
        raise _oauth_http(e)

    # Mobile prefers tokens in JSON; also set cookies for hybrid webviews.
    set_auth_cookies(response, access, refresh)
    return {
        "user": user_public(u),
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
