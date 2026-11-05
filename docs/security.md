# Безопасность

## Авторизация

- JWT access/refresh (python-jose), пароли — argon2
- Web: httpOnly cookies, `SameSite=Lax`, опционально `COOKIE_SECURE` / `COOKIE_DOMAIN`
- CSRF double-submit для cookie-сессий (`verify_csrf`)
- Mobile Bearer освобождён от CSRF
- Сессия: access ~24ч / refresh ~90д; refresh без revoke на каждый вызов (без гонки вкладок)

Middleware Next.js проверяет наличие JWT и `exp` без крипто-верификации (UX-гард); подпись проверяет API.

**Dual auth:** один JWT-контур обслуживает cookies (web) и Bearer (mobile) через общий `get_current_user`.

## RBAC (три оси)

| Ось | Где | Назначение |
|-----|-----|------------|
| `ProjectMemberRole` | `project_members.role` | viewer / member / admin в проекте — основной ACL задач |
| `UserRole.admin` | `users.role` | legacy bootstrap-admin / часть `/api/v1/admin`; **не** даёт все проекты в workspace |
| `platform_role` | `users.platform_role` | UI `/admin` и `/api/v1/platform` (все проекты платформы) |

- Workspace `/projects` — только членство (даже для legacy admin).
- Фронтенд не граница RBAC. ACL задач — `ensure_project_access` через project_id задачи.
- Единый вход: `/login`. Ссылка на `/admin` в профиле, если `platform_role ≠ none`.
- Platform admin ≠ project admin ≠ `/app/admin`.

## Удаление аккаунта

- API: `DELETE /api/v1/users/me`
- UI: профиль web/mobile + страница `/account-delete` (требования магазинов)
- Privacy: `/privacy`

## OAuth

- Secrets только на сервере (`OAUTH_*`)
- PKCE / state; runtime-флаги: `platform_settings.oauth_login_methods` + env
- Apple на web UI отключён; для РФ — 149-ФЗ (`OAUTH_OPERATOR_REGION`, `OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR`)
- Автослияние аккаунтов **только по email запрещено**

См. [oauth.md](oauth.md).

## Секреты

- `.env` в `.gitignore`
- Firebase Admin JSON, `google-services.json`, Apple `.p8`, Android keystore — вне git
- Не логировать токены и пароли
- Demo-учётка (`DEMO_USER_*`) — только локальный `.env` / private, не в git

## Защита API

- SlowAPI rate limits на auth
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`
- Login lockout: in-memory (долг multi-worker)
- Demo isolation: `is_demo`
- WebSocket: предпочтительно Bearer; query-token — только при явном флаге окружения

## Админ-панель

`/admin` после обычной cookie-сессии; права на API по `platform_role`. Без роли — 403.
