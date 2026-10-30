# API v1

Базовый префикс: **`/api/v1`**.  
Swagger / ReDoc: `GET /docs`, `GET /redoc`.  
Health: `GET /health`. WebSocket: `WS /ws`.

## Аутентификация

| Клиент | Механизм |
|--------|----------|
| Web | httpOnly cookies `access_token`, `refresh_token` + `csrf_token`; CSRF-заголовок на POST/PATCH/DELETE |
| Mobile | JSON `access_token` / `refresh_token`; `Authorization: Bearer …` (CSRF не нужен) |

Эндпоинты: `POST /auth/login`, `POST /auth/register/send-code`, `POST /auth/register/confirm`, `POST /auth/forgot-password/send-code`, `POST /auth/forgot-password/confirm`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`.  
OAuth: `GET /auth/oauth/providers`, `GET /auth/oauth/{provider}/start`, callback, `POST /auth/oauth/mobile`.

## Ресурсы

| Ресурс | Примеры |
|--------|---------|
| Projects | `GET/POST /projects`, `GET/PATCH /projects/{id}` |
| Statuses | `GET/POST /settings/statuses?project_id=` |
| Tasks | `GET /tasks?project_id=`, `POST /tasks`, `PATCH/DELETE /tasks/{id}`, `POST …/move` |
| Invites | `GET /invites/mine`, `POST /projects/{id}/invites` |
| Notifications | `GET /notifications`, mark read, device-token |
| Platform | `/platform/*` — только `platform_role` |
| Admin (legacy) | `/admin/*` — `UserRole.admin` / platform |

Списки задач **без** `project_id` ограничены доступными проектами. Доступ к задаче — через membership её проекта.

## Пагинация

`page`, `page_size` (для board часто `page_size=1000`).  
Ответ: `{ "items": [...], "total", "page", "page_size" }`.

## Ошибки

```json
{
  "detail": {
    "error": {
      "code": "forbidden",
      "message": "Нет доступа к проекту"
    }
  }
}
```

Читать `detail.error.message` (и ответы SlowAPI rate-limit).

## Версионирование

Контракт **v1**. Ломающие изменения без миграции клиентов не допускаются.
