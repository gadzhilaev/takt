"""Mobile OAuth launch proxy: only allowlisted authorize hosts."""

from __future__ import annotations

from urllib.parse import parse_qs, urlparse

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.config import Settings
from app.main import app
from app.models.platform import OAuthProvider
from app.services import oauth_service


@pytest.mark.asyncio
async def test_oauth_launch_allows_yandex():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.get(
            "/api/v1/auth/oauth/launch",
            params={"url": "https://oauth.yandex.ru/authorize?client_id=1"},
            follow_redirects=False,
        )
    assert r.status_code == 302
    assert r.headers["location"].startswith("https://oauth.yandex.ru/authorize")


@pytest.mark.asyncio
async def test_oauth_launch_rejects_foreign_host():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.get(
            "/api/v1/auth/oauth/launch",
            params={"url": "https://evil.example/phish"},
            follow_redirects=False,
        )
    assert r.status_code == 400
    assert r.json()["detail"]["error"]["code"] == "invalid_authorize_url"


@pytest.mark.asyncio
async def test_vk_authorize_uses_current_domain_and_pkce_method(monkeypatch):
    redirect_uri = "https://taktapp.ru/api/v1/auth/oauth/callback"
    settings = Settings(
        OAUTH_VK_CLIENT_ID="vk-client",
        OAUTH_VK_CLIENT_SECRET="vk-secret",
        OAUTH_ALLOWED_REDIRECT_URIS=redirect_uri,
    )

    class FakeDb:
        def add(self, _row):
            pass

        async def flush(self):
            pass

    monkeypatch.setattr(oauth_service, "get_settings", lambda: settings)

    async def provider_enabled(*_args, **_kwargs):
        return True

    monkeypatch.setattr(oauth_service, "_provider_enabled", provider_enabled)
    started = await oauth_service.start_oauth(
        FakeDb(), OAuthProvider.vk, redirect_uri=redirect_uri
    )

    authorize = urlparse(started["authorize_url"])
    params = parse_qs(authorize.query)
    assert authorize.scheme == "https"
    assert authorize.netloc == "id.vk.ru"
    assert authorize.path == "/authorize"
    assert params["code_challenge_method"] == ["s256"]
    assert params["redirect_uri"] == [redirect_uri]
    assert params["state"] == [started["state"]]
    assert params["device_id"]
