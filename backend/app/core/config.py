from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parents[2]
_ROOT_DIR = _BACKEND_DIR.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(_BACKEND_DIR / ".env", _ROOT_DIR / ".env"),
        extra="ignore",
    )

    APP_NAME: str = "Takt"
    ENV: str = "development"
    DEBUG: bool = False

    DATABASE_URL: str = "postgresql+asyncpg://track:track_dev_pass@localhost:5433/track"
    SECRET_KEY: str = "change-me-in-production-min-32-chars-long"
    JWT_ALGORITHM: str = "HS256"
    # Access short-ish, refresh long-lived; /auth/refresh renews access without logout.
    # Defaults keep daytime use stable; refresh is reusable (no rotate-on-every-call races).
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24h
    REFRESH_TOKEN_EXPIRE_DAYS: int = 90

    COOKIE_SECURE: bool = False
    COOKIE_DOMAIN: str | None = None
    CORS_ORIGINS: str = "http://localhost:3000"

    ADMIN_EMAIL: str = "admin@example.com"
    ADMIN_PASSWORD: str = "ChangeMeAdmin123!"
    ADMIN_NAME: str = "Администратор"

    UPLOAD_DIR: str = "/data/uploads"
    MAX_UPLOAD_BYTES: int = 10 * 1024 * 1024

    LOGIN_RATE_LIMIT: str = "10/minute"
    LOGIN_LOCKOUT_ATTEMPTS: int = 5
    LOGIN_LOCKOUT_MINUTES: int = 15

    SEED_DEMO_DATA: bool = False

    # Isolated demo workspace (password must come from env / private file — never commit).
    DEMO_USER_EMAIL: str = "demo@example.com"
    DEMO_USER_PASSWORD: str = ""

    # Web Push (VAPID). Leave empty to disable push; in-app notifications still work.
    VAPID_PUBLIC_KEY: str = ""
    VAPID_PRIVATE_KEY: str = ""
    VAPID_SUBJECT: str = "mailto:admin@example.com"
    APP_PUBLIC_URL: str = "http://localhost:3000"

    # Firebase Cloud Messaging (mobile). Path to service-account JSON — never commit the file.
    FIREBASE_CREDENTIALS_FILE: str = ""
    FCM_ENABLED: bool = False

    # Email OTP: SMTP.BZ HTTP API preferred; classic SMTP (connect.smtp.bz) as fallback.
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = True
    SMTP_BZ_API_KEY: str = ""
    SMTP_FROM_EMAIL: str = "Takt <noreply@taktapp.ru>"
    EMAIL_CODE_TTL_MINUTES: int = 10
    EMAIL_CODE_LENGTH: int = 6
    EMAIL_CODE_RESEND_SECONDS: int = 60
    EMAIL_CODE_MAX_ATTEMPTS: int = 5

    # OAuth / OIDC — secrets stay server-side only. Empty = provider disabled.
    OAUTH_WEB_REDIRECT_URI: str = "http://localhost:3000/api/v1/auth/oauth/callback"
    # Mobile VK/Yandex: same HTTPS callback as web (registered in provider consoles).
    # /callback then bounces to OAUTH_MOBILE_DEEP_LINK for ASWebAuthenticationSession.
    OAUTH_MOBILE_REDIRECT_URI: str = "https://taktapp.ru/api/v1/auth/oauth/callback"
    OAUTH_MOBILE_DEEP_LINK: str = "takt://oauth/callback"
    OAUTH_ALLOWED_REDIRECT_URIS: str = (
        "http://localhost:3000/api/v1/auth/oauth/callback,"
        "https://taktapp.ru/api/v1/auth/oauth/callback,"
        "takt://oauth/callback"
    )
    # Operator jurisdiction hint for auth-method policy (ru | global | unset).
    # Does NOT geo-block users by IP. Legal review required before enabling Apple for RU audience.
    OAUTH_OPERATOR_REGION: str = "unset"
    OAUTH_APPLE_ENABLED: bool = False
    OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR: bool = False  # safe default under 149-FZ considerations
    OAUTH_APPLE_CLIENT_ID: str = ""  # Services ID (web) / bundle id handled separately for native
    OAUTH_APPLE_TEAM_ID: str = ""
    OAUTH_APPLE_KEY_ID: str = ""
    OAUTH_APPLE_PRIVATE_KEY: str = ""  # PEM contents or path — never commit real key
    OAUTH_APPLE_PRIVATE_KEY_FILE: str = ""
    OAUTH_VK_ENABLED: bool = False
    OAUTH_VK_CLIENT_ID: str = ""
    OAUTH_VK_CLIENT_SECRET: str = ""
    OAUTH_YANDEX_ENABLED: bool = False
    OAUTH_YANDEX_CLIENT_ID: str = ""
    OAUTH_YANDEX_CLIENT_SECRET: str = ""
    # Encrypt MFA secrets at rest (Fernet key or derived from SECRET_KEY)
    MFA_FERNET_KEY: str = ""

    # WebSocket: ?access_token= fallback for older mobile builds.
    # Prefer Authorization: Bearer (mobile) or access_token cookie (web).
    # Set false after all clients ship header-based WS auth.
    ALLOW_WS_QUERY_TOKEN: bool = True

    # Due-date reminders (in-app + web push + FCM). Interval 0 disables the loop.
    DUE_SOON_HOURS: int = 24
    DUE_REMINDER_INTERVAL_SECONDS: int = 300
    DUE_REMINDER_ENABLED: bool = True

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def oauth_redirect_allowlist(self) -> list[str]:
        return [u.strip() for u in self.OAUTH_ALLOWED_REDIRECT_URIS.split(",") if u.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
