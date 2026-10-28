import secrets

from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from app.core.config import get_settings

CSRF_COOKIE = "csrf_token"
CSRF_HEADER = "X-CSRF-Token"
CSRF_MAX_AGE = 3600 * 24


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(get_settings().SECRET_KEY, salt="csrf")


def generate_csrf_token() -> str:
    return _serializer().dumps(secrets.token_urlsafe(32))


def validate_csrf_token(token: str, cookie_token: str | None) -> bool:
    if not token or not cookie_token:
        return False
    if not secrets.compare_digest(token, cookie_token):
        return False
    try:
        _serializer().loads(cookie_token, max_age=CSRF_MAX_AGE)
        return True
    except (BadSignature, SignatureExpired):
        return False
