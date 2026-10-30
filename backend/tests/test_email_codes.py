import pytest
from httpx import AsyncClient

from tests.conftest import register_verified


@pytest.mark.asyncio
async def test_register_requires_email_code(client: AsyncClient):
    send = await client.post(
        "/api/v1/auth/register/send-code",
        json={
            "name": "Код",
            "email": "otp-reg@example.com",
            "password": "SecurePass123!",
            "password_confirm": "SecurePass123!",
        },
    )
    assert send.status_code == 200, send.text
    assert "dev_code" in send.json()
    bad = await client.post(
        "/api/v1/auth/register/confirm",
        json={"email": "otp-reg@example.com", "code": "000000"},
    )
    assert bad.status_code == 400
    ok = await client.post(
        "/api/v1/auth/register/confirm",
        json={"email": "otp-reg@example.com", "code": send.json()["dev_code"]},
    )
    assert ok.status_code == 200, ok.text
    assert ok.json()["user"]["email"] == "otp-reg@example.com"


@pytest.mark.asyncio
async def test_change_password_requires_email_code(client: AsyncClient):
    await register_verified(client, name="Pwd", email="otp-pwd@example.com")
    send = await client.post(
        "/api/v1/auth/change-password/send-code",
        json={
            "current_password": "SecurePass123!",
            "new_password": "NewSecurePass123!",
            "new_password_confirm": "NewSecurePass123!",
        },
    )
    assert send.status_code == 200, send.text
    code = send.json()["dev_code"]
    confirm = await client.post(
        "/api/v1/auth/change-password/confirm",
        json={"code": code},
    )
    assert confirm.status_code == 200, confirm.text
    # session revoked — login with new password
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "otp-pwd@example.com", "password": "NewSecurePass123!"},
    )
    assert login.status_code == 200, login.text


@pytest.mark.asyncio
async def test_forgot_password_resets_with_email_code(client: AsyncClient):
    await register_verified(client, name="Forgot", email="otp-forgot@example.com")
    await client.post("/api/v1/auth/logout")
    unknown = await client.post(
        "/api/v1/auth/forgot-password/send-code",
        json={"email": "nobody-forgot@example.com"},
    )
    assert unknown.status_code == 404, unknown.text
    assert unknown.json()["detail"]["error"]["code"] == "email_not_found"

    send = await client.post(
        "/api/v1/auth/forgot-password/send-code",
        json={"email": "otp-forgot@example.com"},
    )
    assert send.status_code == 200, send.text
    code = send.json()["dev_code"]
    confirm = await client.post(
        "/api/v1/auth/forgot-password/confirm",
        json={
            "email": "otp-forgot@example.com",
            "code": code,
            "new_password": "ResetSecurePass123!",
            "new_password_confirm": "ResetSecurePass123!",
        },
    )
    assert confirm.status_code == 200, confirm.text
    old = await client.post(
        "/api/v1/auth/login",
        json={"email": "otp-forgot@example.com", "password": "SecurePass123!"},
    )
    assert old.status_code == 401
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "otp-forgot@example.com", "password": "ResetSecurePass123!"},
    )
    assert login.status_code == 200, login.text
