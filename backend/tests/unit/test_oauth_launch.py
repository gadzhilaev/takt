"""Mobile OAuth launch proxy: only allowlisted authorize hosts."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


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
