"""OAuth avatar download from provider photo URL."""

from __future__ import annotations

import uuid
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.user import User, UserRole
from app.services.oauth_service import _maybe_set_avatar_from_url


@pytest.mark.asyncio
async def test_maybe_set_avatar_from_url_saves_png(tmp_path: Path, monkeypatch):
    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))
    from app.core.config import get_settings

    get_settings.cache_clear()

    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x02\x00\x00\x00\x90wS\xde" + b"\x00" * 40
    )
    user = User(
        id=uuid.uuid4(),
        email="oauth-avatar@example.com",
        name="OAuth",
        role=UserRole.member,
        password_hash=None,
        is_active=True,
    )

    resp = MagicMock()
    resp.status_code = 200
    resp.content = png
    resp.headers = {"content-type": "image/png"}

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=resp)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)

    with patch("app.services.oauth_service.httpx.AsyncClient", return_value=mock_client):
        ok = await _maybe_set_avatar_from_url(user, "https://example.com/a.png", force=True)

    assert ok is True
    assert user.avatar_path
    assert Path(user.avatar_path).exists()
    assert Path(user.avatar_path).read_bytes() == png
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_maybe_set_avatar_skips_when_already_set(tmp_path: Path, monkeypatch):
    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))
    from app.core.config import get_settings

    get_settings.cache_clear()
    user = User(
        id=uuid.uuid4(),
        email="has-avatar@example.com",
        name="Has",
        role=UserRole.member,
        password_hash=None,
        is_active=True,
        avatar_path=str(tmp_path / "existing.jpg"),
    )
    ok = await _maybe_set_avatar_from_url(user, "https://example.com/a.png")
    assert ok is False
    get_settings.cache_clear()
