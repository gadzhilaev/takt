"""Mobile OAuth: HTTPS callback must bounce to takt:// without consuming PKCE state."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.oauth import _mobile_deep_link_bounce, oauth_callback_get
from app.core.config import get_settings
from app.models.platform import OAuthLoginState, OAuthProvider


@pytest.mark.asyncio
async def test_mobile_deep_link_bounce_html_contains_takt_scheme():
    resp = _mobile_deep_link_bounce(code="abc", state="st1", device_id="dev")
    assert resp.status_code == 200
    body = resp.body.decode()
    assert "takt://oauth/callback" in body
    assert "code=abc" in body
    assert "state=st1" in body
    assert "device_id=dev" in body
    assert "window.location.replace" in body


@pytest.mark.asyncio
async def test_callback_bounces_mobile_without_finish_web(monkeypatch):
    get_settings.cache_clear()
    state = "mobile-state-xyz"
    row = OAuthLoginState(
        id=uuid.uuid4(),
        state=state,
        provider=OAuthProvider.yandex,
        code_verifier="verifier",
        redirect_uri="https://taktapp.ru/api/v1/auth/oauth/callback",
        client_kind="mobile",
        expires_at=datetime.now(UTC) + timedelta(minutes=10),
    )

    async def fake_row(_db, s: str):
        assert s == state
        return row

    monkeypatch.setattr("app.api.v1.oauth._oauth_state_row", fake_row)

    finish_called = {"n": 0}

    async def fake_finish(*_a, **_k):
        finish_called["n"] += 1
        raise AssertionError("web finish must not run for mobile")

    monkeypatch.setattr("app.api.v1.oauth._finish_web", fake_finish)

    resp = await oauth_callback_get(
        request=MagicMock(),
        db=MagicMock(spec=AsyncSession),
        response=MagicMock(),
        code="auth-code",
        state=state,
        error=None,
        device_id="vk-device",
        provider=None,
    )
    assert finish_called["n"] == 0
    assert resp.status_code == 200
    body = resp.body.decode()
    assert "takt://oauth/callback" in body
    assert "auth-code" in body
    assert state in body
    get_settings.cache_clear()
