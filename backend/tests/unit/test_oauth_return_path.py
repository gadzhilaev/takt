"""Unit tests for OAuth return_path / invite helpers."""

from app.services.oauth_service import invite_token_from_path, sanitize_return_path


def test_sanitize_return_path_allows_invite_and_app():
    assert sanitize_return_path("/invite/abc123") == "/invite/abc123"
    assert sanitize_return_path("/app/projects") == "/app/projects"
    assert sanitize_return_path("/app/projects/x?task=1") == "/app/projects/x?task=1"


def test_sanitize_return_path_rejects_unsafe():
    assert sanitize_return_path(None) is None
    assert sanitize_return_path("") is None
    assert sanitize_return_path("//evil.com") is None
    assert sanitize_return_path("https://evil.com") is None
    assert sanitize_return_path("/login") is None
    assert sanitize_return_path("/register?x=1") is None
    assert sanitize_return_path("/api/v1/auth/me") is None


def test_invite_token_from_path():
    assert invite_token_from_path("/invite/tok_ABC") == "tok_ABC"
    assert invite_token_from_path("/invite/tok?x=1") == "tok"
    assert invite_token_from_path("/app/projects") is None
