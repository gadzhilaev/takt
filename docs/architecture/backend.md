# Архитектура backend (FastAPI)

## Слои

```text
backend/app/
├── main.py              # FastAPI app, lifespan (migrate + bootstrap), CORS, headers
├── api/
│   ├── deps.py          # JWT user, CSRF, platform RBAC deps
│   ├── auth_cookies.py  # set cookies + UserPublic (auth + oauth)
│   ├── serializers.py
│   └── v1/              # HTTP routes, HTTPException mapping
├── services/            # Application / domain logic
├── models/              # SQLAlchemy 2 ORM
├── schemas/             # Pydantic v2 request/response
├── core/                # config, security, csrf, limiter
└── db/session.py        # async engine, get_db
```

Предпочтительный поток: **Route → Service → ORM**. Routes содержат HTTP-маппинг ошибок и CSRF/deps; тяжёлая логика — в services.

## Dependency Injection

FastAPI `Depends`:

- `get_db` — `AsyncSession`, commit при успешном выходе, rollback при исключении  
- `get_current_user` / `get_current_user_optional` — cookie `access_token` **или** Bearer  
- `verify_csrf` — для mutating web; пропускается при Bearer и `ENV=test`  
- `require_platform_*` — платформенные роли  

Project ACL: `project_service.ensure_project_access(db, user, project_id, min_role=…)`.

## Транзакции и сессии

`get_db` (`db/session.py`) — основной boundary транзакции. Некоторые handlers дополнительно вызывают `await db.commit()` перед broadcast WebSocket — осознанный паттерн «зафиксировать, затем уведомить».

## Основные модули API (`/api/v1`)

| Router | Prefix / пути | Назначение |
|--------|---------------|------------|
| `auth` | `/auth` | login, register OTP, refresh, me, password |
| `oauth` | `/auth/oauth` | start/callback/mobile, identities |
| `projects` | `/projects` | CRUD, members, leave |
| `tasks` | `/tasks` | CRUD, move, comments, checklist (+ project ACL) |
| `settings` | `/settings` | статусы (столбцы) проекта |
| `invites` | `/invites`, `/projects/{id}/invites` | приглашения |
| `notifications` | `/notifications` | in-app + device tokens |
| `admin` | `/admin` | legacy workspace admin users |
| `platform` | `/platform` | platform console API |
| `reports` | `/reports` | агрегаты / Excel (API есть; web UI упрощён) |
| `files` | `/files` | avatars/logo |
| `ws` | `/ws` (вне `/api/v1`) | realtime events |

## Ошибки

Контракт: `{"error": {"code": "...", "message": "..."}}` внутри `HTTPException.detail`.  
Сервисные исключения (`AuthError`, `OAuthError`, …) мапятся в routes.  
Необработанные → 500 с общим сообщением (если `DEBUG=false`).

## Уведомления и push

- `notify_service` — in-app rows + вызов push  
- `push_service` — Web Push (VAPID)  
- `fcm_service` — Firebase Admin  

## Известные ограничения (зафиксированы)

- Login lockout (`auth_service`) — **in-memory**, не шарится между воркерами.  
- Pytest поднимает схему через `Base.metadata`, не Alembic.  
- Файлы `tasks.py` / `oauth_service.py` крупные; дробление — поэтапно, без «big bang».
