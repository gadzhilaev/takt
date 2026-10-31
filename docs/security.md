# Безопасность

## Авторизация

- JWT access/refresh (python-jose), пароли — argon2
- Web: httpOnly cookies, `SameSite=Lax`, опционально `COOKIE_SECURE` / `COOKIE_DOMAIN`
- CSRF double-submit для cookie-сессий (`verify_csrf`)
- Mobile Bearer освобождён от CSRF

Middleware Next.js проверяет наличие JWT и `exp` без крипто-верификации (UX-гард); подпись проверяет API.

## RBAC

| Ось | Где | Назначение |
|-----|-----|------------|
| `ProjectMemberRole` | `project_members.role` | viewer / member / admin в проекте |
| `UserRole.admin` | `users.role` | legacy bootstrap-admin (bootstrap / часть admin API); **не** даёт доступ ко всем проектам в workspace |
| `platform_role` | `users.platform_role` | `/admin` UI и `/api/v1/platform` (все проекты платформы) |

Фронтенд не граница RBAC. ACL задач — `ensure_project_access` через project_id задачи.

Единый вход: `/login`. Ссылка на `/admin` показывается в workspace, если `platform_role ≠ none`.

## OAuth

- Secrets только на сервере (`OAUTH_*`)
- PKCE / state; provider может резолвиться из state (VK)
- Runtime-флаги: `platform_settings.oauth_login_methods` + env
- Apple на web UI отключён; для РФ — 149-ФЗ (`OAUTH_OPERATOR_REGION`, `OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR`)

См. [oauth.md](oauth.md).

## Секреты

- `.env` в `.gitignore`
- Firebase Admin JSON, `google-services.json`, Apple `.p8` — вне git
- Не логировать токены и пароли

## Защита API

- SlowAPI rate limits на auth
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`
- Login lockout: in-memory (долг multi-worker)
- Demo isolation: `is_demo`

## Админ-панель

`/admin` после обычной cookie-сессии; права на API по `platform_role`. Без роли — 403.
