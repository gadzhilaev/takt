"""VK ID token exchange must follow its OAuth 2.1 request contract."""

from __future__ import annotations

import pytest

from app.core.config import Settings
from app.services import oauth_service


@pytest.mark.asyncio
async def test_vk_exchange_sends_query_params_and_code_in_form(monkeypatch):
    settings = Settings(OAUTH_VK_CLIENT_ID="vk-client", OAUTH_VK_CLIENT_SECRET="vk-secret")
    monkeypatch.setattr(oauth_service, "get_settings", lambda: settings)
    calls: list[tuple[str, dict]] = []

    class Response:
        status_code = 200

        def __init__(self, body):
            self.body = body

        def json(self):
            return self.body

    class Client:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args):
            return None

        async def post(self, url, **kwargs):
            calls.append((url, kwargs))
            if url == oauth_service.VK_TOKEN:
                return Response(
                    {"access_token": "access", "user_id": 42, "state": "expected-state"}
                )
            return Response({"user": {"user_id": 42, "first_name": "Test"}})

    monkeypatch.setattr(oauth_service.httpx, "AsyncClient", lambda **_kwargs: Client())

    profile = await oauth_service._exchange_vk(
        "authorization-code",
        "https://taktapp.ru/api/v1/auth/oauth/callback",
        "pkce-verifier",
        "device-id",
        "expected-state",
    )

    token_url, token_request = calls[0]
    assert token_url == "https://id.vk.ru/oauth2/auth"
    assert token_request["params"] == {
        "grant_type": "authorization_code",
        "client_id": "vk-client",
        "redirect_uri": "https://taktapp.ru/api/v1/auth/oauth/callback",
        "code_verifier": "pkce-verifier",
        "device_id": "device-id",
        "state": "expected-state",
    }
    assert token_request["data"] == {"code": "authorization-code"}

    info_url, info_request = calls[1]
    assert info_url == "https://id.vk.ru/oauth2/user_info"
    assert info_request["params"] == {"client_id": "vk-client"}
    assert info_request["data"] == {"access_token": "access"}
    assert profile.provider_user_id == "42"
    assert profile.display_name == "Test"


@pytest.mark.asyncio
async def test_vk_exchange_rejects_mismatched_state(monkeypatch):
    class Response:
        status_code = 200

        @staticmethod
        def json():
            return {"access_token": "access", "user_id": 42, "state": "other-state"}

    class Client:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args):
            return None

        async def post(self, *_args, **_kwargs):
            return Response()

    monkeypatch.setattr(oauth_service, "get_settings", lambda: Settings(OAUTH_VK_CLIENT_ID="id"))
    monkeypatch.setattr(oauth_service.httpx, "AsyncClient", lambda **_kwargs: Client())

    with pytest.raises(oauth_service.OAuthError, match="state"):
        await oauth_service._exchange_vk("code", "https://taktapp.ru/callback", "verifier", "device", "expected-state")
