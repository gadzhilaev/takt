"""Apple id_token verification for native Sign in with Apple (mobile_complete)."""

from __future__ import annotations

import base64
import time
from typing import Any
from unittest.mock import AsyncMock, patch

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from jose import jwt

from app.core.config import Settings
from app.services.oauth_service import (
    OAuthError,
    _clear_apple_jwks_cache,
    _decode_unverified_jwt_claims,
    apple_allowed_audiences,
    verify_apple_id_token,
)

BUNDLE = "ru.gadzhilaev.takt"
ISS = "https://appleid.apple.com"


@pytest.fixture()
def rsa_pair():
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    priv_pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    pub = key.public_key().public_numbers()

    def b64u(n: int) -> str:
        length = (n.bit_length() + 7) // 8
        return base64.urlsafe_b64encode(n.to_bytes(length, "big")).rstrip(b"=").decode()

    jwk = {
        "kty": "RSA",
        "kid": "test-kid",
        "use": "sig",
        "alg": "RS256",
        "n": b64u(pub.n),
        "e": b64u(pub.e),
    }
    return priv_pem, jwk


def _apple_claims(**over: Any) -> dict[str, Any]:
    now = int(time.time())
    claims: dict[str, Any] = {
        "iss": ISS,
        "aud": BUNDLE,
        "sub": "001234.abcdef.0100",
        "exp": now + 3600,
        "iat": now,
        "email": "reviewer@privaterelay.appleid.com",
        "email_verified": "true",
    }
    claims.update(over)
    return claims


def _sign(claims: dict[str, Any], priv_pem: bytes, kid: str = "test-kid") -> str:
    return jwt.encode(claims, priv_pem, algorithm="RS256", headers={"kid": kid})


@pytest.fixture(autouse=True)
def _reset_jwks_cache():
    _clear_apple_jwks_cache()
    yield
    _clear_apple_jwks_cache()


def test_decode_unverified_fails_on_apple_aud_when_verify_aud_left_on(rsa_pair):
    """Regression: jose keeps verify_aud=True even with verify_signature=False.

    A real Apple id_token has aud=bundle id; decoding without audience → Invalid audience
    → «Некорректный id_token» on device (App Review 2.1a).
    """
    priv_pem, _ = rsa_pair
    token = _sign(_apple_claims(), priv_pem)
    from jose import jwt as jose_jwt
    from jose.exceptions import JWTClaimsError

    with pytest.raises(JWTClaimsError, match="audience"):
        jose_jwt.decode(token, key="", options={"verify_signature": False})


def test_decode_unverified_helper_accepts_apple_shaped_token(rsa_pair):
    """Web TLS path helper must not choke on aud (signature still unchecked there)."""
    priv_pem, _ = rsa_pair
    token = _sign(_apple_claims(), priv_pem)
    claims = _decode_unverified_jwt_claims(token)
    assert claims["aud"] == BUNDLE
    assert claims["iss"] == ISS
    assert claims["sub"]


@pytest.mark.asyncio
async def test_verify_accepts_valid_token_with_mocked_jwks(rsa_pair):
    priv_pem, jwk = rsa_pair
    token = _sign(_apple_claims(), priv_pem)
    settings = Settings(OAUTH_APPLE_CLIENT_ID="com.example.svc", OAUTH_APPLE_AUDIENCES="")

    async def fake_fetch(*, force: bool = False):
        return {"keys": [jwk]}

    with patch("app.services.oauth_service._fetch_apple_jwks", new=AsyncMock(side_effect=fake_fetch)):
        claims = await verify_apple_id_token(token, settings=settings)
    assert claims["sub"] == "001234.abcdef.0100"
    assert claims["email"] == "reviewer@privaterelay.appleid.com"


@pytest.mark.asyncio
async def test_verify_rejects_wrong_signature(rsa_pair):
    priv_pem, jwk = rsa_pair
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    other_pem = other.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    token = _sign(_apple_claims(), other_pem)  # signed by foreign key

    async def fake_fetch(*, force: bool = False):
        return {"keys": [jwk]}

    with patch("app.services.oauth_service._fetch_apple_jwks", new=AsyncMock(side_effect=fake_fetch)):
        with pytest.raises(OAuthError) as ei:
            await verify_apple_id_token(token, settings=Settings())
    assert ei.value.code == "bad_token"


@pytest.mark.asyncio
async def test_verify_rejects_wrong_audience(rsa_pair):
    priv_pem, jwk = rsa_pair
    token = _sign(_apple_claims(aud="com.evil.app"), priv_pem)

    async def fake_fetch(*, force: bool = False):
        return {"keys": [jwk]}

    with patch("app.services.oauth_service._fetch_apple_jwks", new=AsyncMock(side_effect=fake_fetch)):
        with pytest.raises(OAuthError) as ei:
            await verify_apple_id_token(token, settings=Settings())
    assert ei.value.code == "bad_token"


@pytest.mark.asyncio
async def test_verify_rejects_expired(rsa_pair):
    priv_pem, jwk = rsa_pair
    token = _sign(_apple_claims(exp=int(time.time()) - 3600, iat=int(time.time()) - 7200), priv_pem)

    async def fake_fetch(*, force: bool = False):
        return {"keys": [jwk]}

    with patch("app.services.oauth_service._fetch_apple_jwks", new=AsyncMock(side_effect=fake_fetch)):
        with pytest.raises(OAuthError) as ei:
            await verify_apple_id_token(token, settings=Settings())
    assert ei.value.code == "bad_token"


@pytest.mark.asyncio
async def test_verify_nonce_optional_but_checked_when_sent(rsa_pair):
    priv_pem, jwk = rsa_pair
    token = _sign(_apple_claims(nonce="abc123"), priv_pem)

    async def fake_fetch(*, force: bool = False):
        return {"keys": [jwk]}

    with patch("app.services.oauth_service._fetch_apple_jwks", new=AsyncMock(side_effect=fake_fetch)):
        # build 11: no nonce → ok
        ok = await verify_apple_id_token(token, settings=Settings())
        assert ok["sub"]
        with pytest.raises(OAuthError):
            await verify_apple_id_token(token, nonce="wrong", settings=Settings())
        ok2 = await verify_apple_id_token(token, nonce="abc123", settings=Settings())
        assert ok2["sub"]


def test_apple_allowed_audiences_defaults():
    s = Settings(OAUTH_APPLE_CLIENT_ID="com.takt.svc", OAUTH_APPLE_AUDIENCES="")
    assert apple_allowed_audiences(s) == [BUNDLE, "com.takt.svc"]
    s2 = Settings(OAUTH_APPLE_AUDIENCES="ru.gadzhilaev.takt, com.custom")
    assert apple_allowed_audiences(s2) == [BUNDLE, "com.custom"]
