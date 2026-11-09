"""Refresh must reuse the same token so parallel clients do not kill the session."""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.services import auth_service


class _ScalarResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


@pytest.mark.asyncio
async def test_refresh_reuses_refresh_token(monkeypatch):
    user_id = uuid4()
    jti = "jti-stable"
    user = SimpleNamespace(
        id=user_id,
        role=SimpleNamespace(value="member"),
        is_active=True,
        last_login_at=datetime.now(UTC),
    )
    stored = SimpleNamespace(
        jti=jti,
        user_id=user_id,
        revoked_at=None,
        expires_at=datetime.now(UTC) + timedelta(days=60),
    )

    async def fake_execute(stmt):  # noqa: ARG001
        # First query: RefreshToken by jti; second: User by id
        if not hasattr(fake_execute, "n"):
            fake_execute.n = 0
        fake_execute.n += 1
        return _ScalarResult(stored if fake_execute.n == 1 else user)

    db = MagicMock()
    db.execute = AsyncMock(side_effect=fake_execute)
    db.flush = AsyncMock()

    monkeypatch.setattr(
        "app.core.security.decode_token",
        lambda _t: {
            "type": "refresh",
            "jti": jti,
            "sub": str(user_id),
            "exp": int((datetime.now(UTC) + timedelta(days=60)).timestamp()),
        },
    )
    monkeypatch.setattr(
        "app.core.security.create_access_token",
        lambda sub, extra=None: f"access-for-{sub}",
    )

    access, refresh, out_user = await auth_service.refresh_session(db, "raw-refresh-jwt")
    assert access.startswith("access-for-")
    assert refresh == "raw-refresh-jwt"
    assert out_user is user
    # Must not rotate/revoke on a healthy long-lived refresh.
    assert not any(
        getattr(c, "args", None) and "revoked" in str(c).lower()
        for c in db.method_calls
    )
