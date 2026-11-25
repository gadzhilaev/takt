"""OAuth 2.1 authorization server endpoints used by remote MCP clients."""

from __future__ import annotations

import base64
import hashlib
import html
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated
from urllib.parse import urlencode, urlparse

from fastapi import APIRouter, Depends, Form, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, Response
from jose import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.csrf import CSRF_COOKIE, generate_csrf_token, validate_csrf_token
from app.core.limiter import limiter
from app.core.security import decode_token
from app.db.session import get_db
from app.models.mcp_oauth import MCPAuthorizationCode, MCPOAuthClient, MCPRefreshGrant
from app.models.user import User

router = APIRouter(tags=["mcp-oauth"])
MCP_SCOPE = "mcp"
OFFLINE_SCOPE = "offline_access"
ACCESS_TOKEN_SECONDS = 600
AUTH_CODE_SECONDS = 300
REFRESH_TOKEN_DAYS = 30


def _issuer() -> str:
    return get_settings().APP_PUBLIC_URL.rstrip("/")


def _resource() -> str:
    return f"{_issuer()}/mcp"


def _json_error(error: str, status: int = 400, description: str | None = None) -> JSONResponse:
    body = {"error": error}
    if description:
        body["error_description"] = description
    return JSONResponse(
        body,
        status_code=status,
        headers={"Cache-Control": "no-store", "Pragma": "no-cache"},
    )


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _valid_redirect_uri(uri: str) -> bool:
    parsed = urlparse(uri)
    return parsed.scheme == "https" and bool(parsed.netloc) and not parsed.fragment


def _with_query(uri: str, values: dict[str, str]) -> str:
    from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

    parts = urlsplit(uri)
    query = parse_qsl(parts.query, keep_blank_values=True)
    query.extend(values.items())
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), ""))


def _access_token(user_id: uuid.UUID, client_id: str, resource: str, scope: str) -> str:
    now = datetime.now(UTC)
    settings = get_settings()
    claims = {
        "sub": str(user_id),
        "iss": _issuer(),
        "aud": resource,
        "iat": now,
        "exp": now + timedelta(seconds=ACCESS_TOKEN_SECONDS),
        "jti": secrets.token_urlsafe(18),
        "type": "access",
        "scope": scope,
        "oauth_client_id": client_id,
    }
    return jwt.encode(claims, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


async def _current_user(request: Request, db: AsyncSession) -> User | None:
    from app.api.deps import ACCESS_COOKIE, _token_from_auth_header

    token = request.cookies.get(ACCESS_COOKIE) or _token_from_auth_header(
        request.headers.get("authorization")
    )
    payload = decode_token(token) if token else None
    if not payload or payload.get("type") != "access":
        return None
    try:
        user = await db.get(User, uuid.UUID(payload["sub"]))
    except (KeyError, TypeError, ValueError):
        return None
    if not user or not user.is_active:
        return None
    if user.blocked_until and user.blocked_until > datetime.now(UTC):
        return None
    return user


@router.get("/.well-known/oauth-protected-resource")
@router.get("/.well-known/oauth-protected-resource/mcp")
@router.get("/mcp/.well-known/oauth-protected-resource")
async def protected_resource_metadata() -> dict:
    return {
        "resource": _resource(),
        "authorization_servers": [_issuer()],
        "scopes_supported": [MCP_SCOPE, OFFLINE_SCOPE],
        "resource_documentation": f"{_issuer()}/docs/mcp",
        "bearer_methods_supported": ["header"],
    }


@router.get("/.well-known/oauth-authorization-server")
async def authorization_server_metadata() -> dict:
    issuer = _issuer()
    return {
        "issuer": issuer,
        "authorization_endpoint": f"{issuer}/oauth/authorize",
        "token_endpoint": f"{issuer}/oauth/token",
        "registration_endpoint": f"{issuer}/oauth/register",
        "scopes_supported": [MCP_SCOPE, OFFLINE_SCOPE],
        "response_types_supported": ["code"],
        "response_modes_supported": ["query"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "token_endpoint_auth_methods_supported": ["none"],
        "code_challenge_methods_supported": ["S256"],
        "authorization_response_iss_parameter_supported": True,
    }


@router.post("/oauth/register")
@limiter.limit("20/minute")
async def register_client(request: Request, db: Annotated[AsyncSession, Depends(get_db)]):
    try:
        body = await request.json()
    except Exception:
        return _json_error("invalid_client_metadata")
    if not isinstance(body, dict):
        return _json_error("invalid_client_metadata")
    name = body.get("client_name") or body.get("application_type") or "MCP client"
    redirects = body.get("redirect_uris")
    if not isinstance(name, str) or not name.strip() or len(name) > 200:
        return _json_error("invalid_client_metadata")
    if (
        not isinstance(redirects, list)
        or not redirects
        or len(redirects) > 20
        or not all(isinstance(uri, str) and _valid_redirect_uri(uri) for uri in redirects)
    ):
        return _json_error("invalid_redirect_uri")
    client_id = secrets.token_urlsafe(36)
    db.add(MCPOAuthClient(client_id=client_id, client_name=name.strip(), redirect_uris=redirects))
    await db.flush()
    now = int(datetime.now(UTC).timestamp())
    return JSONResponse(
        {
            "client_id": client_id,
            "client_id_issued_at": now,
            "client_name": name.strip(),
            "redirect_uris": redirects,
            "token_endpoint_auth_method": "none",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
        },
        status_code=201,
        headers={"Cache-Control": "no-store"},
    )


@router.get("/oauth/authorize", response_class=HTMLResponse)
async def authorize(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    response_type: str = Query(default=""),
    client_id: str = Query(default=""),
    redirect_uri: str = Query(default=""),
    state: str = Query(default=""),
    code_challenge: str = Query(default=""),
    code_challenge_method: str = Query(default=""),
    resource: str = Query(default=""),
    scope: str = Query(default=""),
):
    client = await db.get(MCPOAuthClient, client_id) if client_id else None
    if (
        not client
        or redirect_uri not in client.redirect_uris
        or not _valid_redirect_uri(redirect_uri)
    ):
        return _json_error("invalid_request", description="Unknown client or redirect URI")
    if response_type != "code" or not state or code_challenge_method != "S256":
        return RedirectResponse(
            _with_query(
                redirect_uri,
                {"error": "invalid_request", "state": state, "iss": _issuer()},
            ),
            status_code=302,
        )
    if len(code_challenge) < 43 or len(code_challenge) > 128:
        return RedirectResponse(
            _with_query(
                redirect_uri,
                {"error": "invalid_request", "state": state, "iss": _issuer()},
            ),
            status_code=302,
        )
    if resource and resource != _resource():
        return RedirectResponse(
            _with_query(
                redirect_uri,
                {"error": "invalid_target", "state": state, "iss": _issuer()},
            ),
            status_code=302,
        )
    requested_scopes = set(scope.split()) if scope else {MCP_SCOPE, OFFLINE_SCOPE}
    if (
        not requested_scopes.issubset({MCP_SCOPE, OFFLINE_SCOPE})
        or MCP_SCOPE not in requested_scopes
    ):
        return RedirectResponse(
            _with_query(
                redirect_uri,
                {"error": "invalid_scope", "state": state, "iss": _issuer()},
            ),
            status_code=302,
        )

    user = await _current_user(request, db)
    if user is None:
        path = request.url.path + "?" + urlencode(request.query_params.multi_items())
        return RedirectResponse(
            f"{get_settings().APP_PUBLIC_URL.rstrip('/')}/login?{urlencode({'next': path})}",
            status_code=302,
        )

    csrf = generate_csrf_token()
    safe_name = html.escape(client.client_name)
    safe_client_id = html.escape(client_id, quote=True)
    safe_redirect = html.escape(redirect_uri, quote=True)
    safe_state = html.escape(state, quote=True)
    safe_challenge = html.escape(code_challenge, quote=True)
    safe_resource = html.escape(_resource(), quote=True)
    safe_scope = html.escape(" ".join(sorted(requested_scopes)), quote=True)
    content = f"""<!doctype html>
<html lang="ru">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Доступ к Takt</title><style>
body{{
  margin:0;background:#f4f6f7;color:#182126;
  font:16px system-ui,sans-serif;display:grid;
  min-height:100vh;place-items:center
}}
main{{
  background:white;border:1px solid #d8e0e4;border-radius:18px;
  padding:28px;max-width:520px;margin:20px;
  box-shadow:0 12px 40px #18212618
}}
h1{{font-size:24px;margin:0 0 8px}}
p{{line-height:1.5;color:#52616a}}
ul{{padding-left:22px;line-height:1.8}}
button{{border:0;border-radius:10px;padding:12px 18px;font-weight:600;cursor:pointer}}
.allow{{background:#315f72;color:white}}
.deny{{background:#eef1f2;color:#26343b;margin-left:8px}}
</style><main><h1>Разрешить доступ к Takt?</h1>
<p><strong>{safe_name}</strong> просит доступ к аккаунту Takt пользователя
<strong>{html.escape(user.email)}</strong>.</p>
<ul><li>Просматривать проекты и задачи, к которым у вас есть доступ.</li>
<li>Создавать и изменять задачи, комментарии и чек-листы.</li>
<li>Перемещать и архивировать задачи; удаление в Takt — обратимое (soft delete).</li></ul>
<p>Вход выполняется на сайте Takt. Ваш пароль не передаётся приложению.</p>
<form method="post" action="/oauth/authorize/consent">
<input type="hidden" name="csrf" value="{html.escape(csrf, quote=True)}">
<input type="hidden" name="client_id" value="{safe_client_id}">
<input type="hidden" name="redirect_uri" value="{safe_redirect}">
<input type="hidden" name="state" value="{safe_state}">
<input type="hidden" name="code_challenge" value="{safe_challenge}">
<input type="hidden" name="resource" value="{safe_resource}">
<input type="hidden" name="scope" value="{safe_scope}">
<button class="allow" name="decision" value="allow">Разрешить</button>
<button class="deny" name="decision" value="deny">Отмена</button></form></main></html>"""
    html_response = HTMLResponse(content, headers={"Cache-Control": "no-store"})
    html_response.set_cookie(
        CSRF_COOKIE,
        csrf,
        httponly=False,
        secure=get_settings().COOKIE_SECURE,
        samesite="lax",
        path="/",
        max_age=24 * 60 * 60,
    )
    return html_response


@router.post("/oauth/authorize/consent")
@limiter.limit("20/minute")
async def consent(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    csrf: Annotated[str, Form()],
    client_id: Annotated[str, Form()],
    redirect_uri: Annotated[str, Form()],
    state: Annotated[str, Form()],
    code_challenge: Annotated[str, Form()],
    resource: Annotated[str, Form()],
    scope: Annotated[str, Form()],
    decision: Annotated[str, Form()],
):
    if not validate_csrf_token(csrf, request.cookies.get(CSRF_COOKIE)):
        return _json_error("invalid_request", status=403)
    client = await db.get(MCPOAuthClient, client_id)
    user = await _current_user(request, db)
    if (
        not client
        or redirect_uri not in client.redirect_uris
        or not _valid_redirect_uri(redirect_uri)
        or resource != _resource()
        or not user
    ):
        return _json_error("invalid_request", status=400)
    scopes = set(scope.split())
    if MCP_SCOPE not in scopes or not scopes.issubset({MCP_SCOPE, OFFLINE_SCOPE}):
        return _json_error("invalid_scope")
    if decision != "allow":
        return RedirectResponse(
            _with_query(
                redirect_uri,
                {"error": "access_denied", "state": state, "iss": _issuer()},
            ),
            status_code=302,
        )
    raw_code = secrets.token_urlsafe(48)
    db.add(
        MCPAuthorizationCode(
            code_hash=_digest(raw_code),
            client_id=client_id,
            user_id=user.id,
            redirect_uri=redirect_uri,
            code_challenge=code_challenge,
            resource=resource,
            scope=scope,
            expires_at=datetime.now(UTC) + timedelta(seconds=AUTH_CODE_SECONDS),
        )
    )
    await db.flush()
    return RedirectResponse(
        _with_query(redirect_uri, {"code": raw_code, "state": state, "iss": _issuer()}),
        status_code=302,
    )


@router.post("/oauth/token")
@limiter.limit("60/minute")
async def token(request: Request, db: Annotated[AsyncSession, Depends(get_db)]):
    try:
        form = await request.form()
    except Exception:
        return _json_error("invalid_request")
    grant_type = str(form.get("grant_type") or "")
    client_id = str(form.get("client_id") or "")
    client = await db.get(MCPOAuthClient, client_id) if client_id else None
    if not client:
        return _json_error("invalid_client", status=401)

    if grant_type == "authorization_code":
        code = str(form.get("code") or "")
        redirect_uri = str(form.get("redirect_uri") or "")
        verifier = str(form.get("code_verifier") or "")
        resource = str(form.get("resource") or _resource())
        row = await db.scalar(
            select(MCPAuthorizationCode)
            .where(MCPAuthorizationCode.code_hash == _digest(code))
            .with_for_update()
        ) if code else None
        if (
            not row
            or row.used_at is not None
            or row.expires_at <= datetime.now(UTC)
            or row.client_id != client_id
            or row.redirect_uri != redirect_uri
            or row.resource != resource
            or len(verifier) < 43
            or len(verifier) > 128
        ):
            return _json_error("invalid_grant")
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest())
        expected = challenge.rstrip(b"=").decode()
        if not secrets.compare_digest(expected, row.code_challenge):
            return _json_error("invalid_grant")
        row.used_at = datetime.now(UTC)
        user_id, scope = row.user_id, row.scope
    elif grant_type == "refresh_token":
        raw_refresh = str(form.get("refresh_token") or "")
        resource = str(form.get("resource") or _resource())
        grant = await db.scalar(
            select(MCPRefreshGrant)
            .where(MCPRefreshGrant.token_hash == _digest(raw_refresh))
            .with_for_update()
        ) if raw_refresh else None
        if (
            not grant
            or grant.revoked_at is not None
            or grant.expires_at <= datetime.now(UTC)
            or grant.client_id != client_id
            or grant.resource != resource
        ):
            return _json_error("invalid_grant")
        grant.revoked_at = datetime.now(UTC)
        user_id, scope = grant.user_id, grant.scope
    else:
        return _json_error("unsupported_grant_type")

    user = await db.get(User, user_id)
    if (
        not user
        or not user.is_active
        or (user.blocked_until and user.blocked_until > datetime.now(UTC))
    ):
        return _json_error("invalid_grant")
    refresh = secrets.token_urlsafe(48)
    db.add(
        MCPRefreshGrant(
            token_hash=_digest(refresh),
            client_id=client_id,
            user_id=user.id,
            resource=resource,
            scope=scope,
            expires_at=datetime.now(UTC) + timedelta(days=REFRESH_TOKEN_DAYS),
        )
    )
    await db.flush()
    return JSONResponse(
        {
            "access_token": _access_token(user.id, client_id, resource, scope),
            "token_type": "Bearer",
            "expires_in": ACCESS_TOKEN_SECONDS,
            "refresh_token": refresh,
            "scope": scope,
        },
        headers={"Cache-Control": "no-store", "Pragma": "no-cache"},
    )


@router.post("/oauth/revoke")
async def revoke(request: Request, db: Annotated[AsyncSession, Depends(get_db)]):
    try:
        form = await request.form()
    except Exception:
        return Response(status_code=200)
    client_id = str(form.get("client_id") or "")
    raw_token = str(form.get("token") or "")
    if client_id and raw_token:
        grant = await db.scalar(
            select(MCPRefreshGrant).where(MCPRefreshGrant.token_hash == _digest(raw_token))
        )
        if grant and grant.client_id == client_id and grant.revoked_at is None:
            grant.revoked_at = datetime.now(UTC)
            await db.flush()
    return Response(status_code=200, headers={"Cache-Control": "no-store"})
