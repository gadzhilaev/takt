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
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

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

    # Email OTP: classic SMTP (connect.smtp.bz) and/or SMTP.BZ HTTP API.
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

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
