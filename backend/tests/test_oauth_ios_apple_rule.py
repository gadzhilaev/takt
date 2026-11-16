"""Guideline 4.8: на iOS VK ID / Яндекс ID показываются только вместе с Sign in with Apple."""

import pytest
from httpx import AsyncClient

from app.core.config import get_settings
from app.services.oauth_service import APPLE_REQUIRED_ON_IOS, provider_availability

_VK_YANDEX = {
    "OAUTH_VK_ENABLED": True,
    "OAUTH_VK_CLIENT_ID": "vk-id",
    "OAUTH_VK_CLIENT_SECRET": "vk-secret",
    "OAUTH_YANDEX_ENABLED": True,
    "OAUTH_YANDEX_CLIENT_ID": "ya-id",
    "OAUTH_YANDEX_CLIENT_SECRET": "ya-secret",
}
_APPLE = {
    "OAUTH_APPLE_ENABLED": True,
    "OAUTH_APPLE_CLIENT_ID": "ru.example.app",
    "OAUTH_APPLE_TEAM_ID": "TEAM",
    "OAUTH_APPLE_KEY_ID": "KEY",
    "OAUTH_APPLE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----",
}


def _settings(**update):
    return get_settings().model_copy(update=update)


def _enabled(body: dict) -> dict[str, bool]:
    return {k: v["enabled"] for k, v in body["providers"].items()}


@pytest.mark.asyncio
async def test_ios_hides_vk_yandex_when_apple_blocked_by_ru_policy():
    s = _settings(
        **_VK_YANDEX,
        **_APPLE,
        OAUTH_OPERATOR_REGION="ru",
        OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR=False,
    )
    ios = await provider_availability(None, s, client="ios")
    assert _enabled(ios) == {"apple": False, "vk": False, "yandex": False}
    assert ios["providers"]["vk"]["reason"] == APPLE_REQUIRED_ON_IOS
    assert ios["providers"]["yandex"]["reason"] == APPLE_REQUIRED_ON_IOS
    assert ios["client"] == "ios"

    # Web / Android не затрагиваются.
    for client in (None, "android", "web"):
        other = await provider_availability(None, s, client=client)
        assert _enabled(other) == {"apple": False, "vk": True, "yandex": True}
        assert other["providers"]["vk"]["reason"] is None


@pytest.mark.asyncio
async def test_ios_hides_vk_yandex_when_apple_not_configured():
    s = _settings(**_VK_YANDEX, OAUTH_APPLE_ENABLED=False)
    ios = await provider_availability(None, s, client="IOS")
    assert _enabled(ios) == {"apple": False, "vk": False, "yandex": False}


@pytest.mark.asyncio
async def test_ios_shows_all_when_apple_enabled():
    s = _settings(
        **_VK_YANDEX,
        **_APPLE,
        OAUTH_OPERATOR_REGION="ru",
        OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR=True,
    )
    ios = await provider_availability(None, s, client="ios")
    assert _enabled(ios) == {"apple": True, "vk": True, "yandex": True}
    assert ios["providers"]["vk"]["reason"] is None


@pytest.mark.asyncio
async def test_ios_never_has_third_party_without_apple_matrix():
    """Перебор комбинаций: на iOS не бывает «VK/Яндекс есть, Apple нет»."""
    for apple_on in (True, False):
        for ru_allowed in (True, False):
            for vk_on in (True, False):
                for ya_on in (True, False):
                    s = _settings(
                        **{
                            **_VK_YANDEX,
                            **_APPLE,
                            "OAUTH_APPLE_ENABLED": apple_on,
                            "OAUTH_OPERATOR_REGION": "ru",
                            "OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR": ru_allowed,
                            "OAUTH_VK_ENABLED": vk_on,
                            "OAUTH_YANDEX_ENABLED": ya_on,
                        }
                    )
                    e = _enabled(await provider_availability(None, s, client="ios"))
                    if e["vk"] or e["yandex"]:
                        assert e["apple"], (apple_on, ru_allowed, vk_on, ya_on)


@pytest.mark.asyncio
async def test_providers_endpoint_accepts_client_param(client: AsyncClient):
    r = await client.get("/api/v1/auth/oauth/providers", params={"client": "ios"})
    assert r.status_code == 200
    body = r.json()
    assert body["client"] == "ios"
    if body["providers"]["vk"]["enabled"] or body["providers"]["yandex"]["enabled"]:
        assert body["providers"]["apple"]["enabled"] is True
