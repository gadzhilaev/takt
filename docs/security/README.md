# Безопасность

## Авторизация

- JWT access/refresh (python-jose), пароли — argon2  
- Web: httpOnly cookies, `SameSite=Lax`, опционально `COOKIE_SECURE` / `COOKIE_DOMAIN`  
- CSRF double-submit для cookie-сессий (`verify_csrf`)  
- Mobile Bearer освобождён от CSRF  

Middleware Next.js проверяет **наличие** JWT и `exp` без крипто-верификации — это UX-гард; реальная проверка подписи на API.

## RBAC

| Ось | Где | Назначение |
|-----|-----|------------|
| `ProjectMemberRole` | `project_members.role` | viewer / member / admin внутри проекта |
| `UserRole.admin` | `users.role` | legacy «системный» admin: доступ к **non-demo** проектам как project admin |
| `platform_role` | `users.platform_role` | `/admin` UI и `/api/v1/platform` |

Фронтенд **не** является границей RBAC. ACL задач завязан на `ensure_project_access` через project_id задачи.

## OAuth

- Secrets только на сервере (`OAUTH_*`)  
- PKCE / state; callback может резолвить provider из state (VK)  
- Runtime-флаги: `platform_settings.oauth_login_methods` + env enabled  
- Apple на web UI отключён; для оператора РФ — политика 149-ФЗ (`OAUTH_OPERATOR_REGION`, `OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR`)  

См. [../OAUTH_SETUP.md](../OAUTH_SETUP.md).

## Секреты

- `.env` в `.gitignore`  
- Firebase Admin JSON, `google-services.json`, Apple `.p8` — вне git  
- Не логировать токены и тела паролей  

## Защита API

- SlowAPI rate limits на auth  
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`  
- Login lockout: in-memory (ограничение multi-worker — известный долг)  
- Demo isolation: `is_demo`  

## Админ-панель

`/admin` доступен после cookie-сессии; **права** проверяются API `platform_role`. UI может прятать пункты, но без роли запросы получат 403.
