import base64
import hashlib
from urllib.parse import parse_qs, urlparse

import pytest

from app.core.config import get_settings


def _pkce_pair() -> tuple[str, str]:
    verifier = "a" * 43
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest())
    return verifier, challenge.rstrip(b"=").decode()


@pytest.mark.asyncio
async def test_mcp_oauth_discovery_and_authorization_code_refresh(admin_client):
    metadata = await admin_client.get("/.well-known/oauth-protected-resource")
    assert metadata.status_code == 200
    assert metadata.json()["resource"] == f"{get_settings().APP_PUBLIC_URL.rstrip('/')}/mcp"
    assert metadata.json()["authorization_servers"] == [get_settings().APP_PUBLIC_URL.rstrip("/")]
    path_metadata = await admin_client.get("/.well-known/oauth-protected-resource/mcp")
    assert path_metadata.status_code == 200
    assert path_metadata.json() == metadata.json()

    authorization_server = await admin_client.get("/.well-known/oauth-authorization-server")
    assert authorization_server.status_code == 200
    assert authorization_server.json()["code_challenge_methods_supported"] == ["S256"]
    assert authorization_server.json()["authorization_response_iss_parameter_supported"] is True

    registered = await admin_client.post(
        "/oauth/register",
        json={
            "client_name": "ChatGPT test",
            "redirect_uris": ["https://chatgpt.com/oauth/callback"],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none",
        },
    )
    assert registered.status_code == 201, registered.text
    client_id = registered.json()["client_id"]
    verifier, challenge = _pkce_pair()
    params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": "https://chatgpt.com/oauth/callback",
        "state": "state-value",
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "resource": metadata.json()["resource"],
        "scope": "mcp offline_access",
    }
    consent_page = await admin_client.get("/oauth/authorize", params=params)
    assert consent_page.status_code == 200
    assert "Разрешить доступ к Takt?" in consent_page.text
    csrf = admin_client.cookies.get("csrf_token")
    assert csrf

    consent_result = await admin_client.post(
        "/oauth/authorize/consent",
        data={
            "csrf": csrf,
            "client_id": client_id,
            "redirect_uri": params["redirect_uri"],
            "state": params["state"],
            "code_challenge": challenge,
            "resource": params["resource"],
            "scope": params["scope"],
            "decision": "allow",
        },
        follow_redirects=False,
    )
    assert consent_result.status_code == 302
    callback = parse_qs(urlparse(consent_result.headers["location"]).query)
    assert callback["state"] == [params["state"]]
    assert callback["iss"] == [get_settings().APP_PUBLIC_URL.rstrip("/")]

    wrong_pkce = await admin_client.post(
        "/oauth/token",
        data={
            "grant_type": "authorization_code",
            "client_id": client_id,
            "code": callback["code"][0],
            "redirect_uri": params["redirect_uri"],
            "code_verifier": "b" * 43,
            "resource": params["resource"],
        },
    )
    assert wrong_pkce.status_code == 400
    assert wrong_pkce.json()["error"] == "invalid_grant"

    token = await admin_client.post(
        "/oauth/token",
        data={
            "grant_type": "authorization_code",
            "client_id": client_id,
            "code": callback["code"][0],
            "redirect_uri": params["redirect_uri"],
            "code_verifier": verifier,
            "resource": params["resource"],
        },
    )
    assert token.status_code == 200, token.text
    token_data = token.json()
    assert token_data["token_type"] == "Bearer"
    assert token_data["expires_in"] == 600
    assert token_data["scope"] == "mcp offline_access"

    replay = await admin_client.post(
        "/oauth/token",
        data={
            "grant_type": "authorization_code",
            "client_id": client_id,
            "code": callback["code"][0],
            "redirect_uri": params["redirect_uri"],
            "code_verifier": verifier,
            "resource": params["resource"],
        },
    )
    assert replay.status_code == 400
    assert replay.json()["error"] == "invalid_grant"

    refreshed = await admin_client.post(
        "/oauth/token",
        data={
            "grant_type": "refresh_token",
            "client_id": client_id,
            "refresh_token": token_data["refresh_token"],
            "resource": params["resource"],
        },
    )
    assert refreshed.status_code == 200, refreshed.text
    assert refreshed.json()["refresh_token"] != token_data["refresh_token"]


@pytest.mark.asyncio
async def test_mcp_oauth_rejects_insecure_redirect(admin_client):
    bad_client = await admin_client.post(
        "/oauth/register",
        json={"client_name": "bad", "redirect_uris": ["http://localhost/callback"]},
    )
    assert bad_client.status_code == 400

    malformed_client = await admin_client.post("/oauth/register", json=[])
    assert malformed_client.status_code == 400
