# API v1

Базовый префикс: **`/api/v1`**.  
Интерактивная схема: `GET /docs` (Swagger) и `GET /redoc` при запущенном backend.  
Health: `GET /health` (вне v1). WebSocket: `WS /ws`.

## Аутентификация

| Клиент | Механизм |
|--------|----------|
| Web | httpOnly cookies `access_token`, `refresh_token` + cookie `csrf_token`; заголовок CSRF на POST/PATCH/DELETE |
| Mobile | JSON `access_token` / `refresh_token`; заголовок `Authorization: Bearer …` (CSRF не требуется) |

Основные эндпоинты: `POST /auth/login`, `POST /auth/register/send-code`, `POST /auth/register/confirm`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`.  
OAuth: `GET /auth/oauth/providers`, `GET /auth/oauth/{provider}/start`, callback, `POST /auth/oauth/mobile`.

## Ресурсы (кратко)

| Ресурс | Примеры |
|--------|---------|
| Projects | `GET/POST /projects`, `GET/PATCH /projects/{id}` |
| Statuses | `GET/POST /settings/statuses?project_id=` |
| Tasks | `GET /tasks?project_id=`, `POST /tasks`, `PATCH/DELETE /tasks/{id}`, `POST …/move` |
| Invites | `GET /invites/mine`, `POST /projects/{id}/invites` |
| Notifications | `GET /notifications`, mark read, device-token |
| Platform | `/platform/*` — только `platform_role` |
| Admin (legacy) | `/admin/*` — `UserRole.admin` / platform |

Списки задач **без** `project_id` ограничены проектами, доступными текущему пользователю. Доступ к конкретной задаче требует membership её проекта.

## Пагинация

Типично: `page`, `page_size` (потолок зависит от эндпоинта; для board часто `page_size=1000`).  
Ответ списка: `{ "items": [...], "total", "page", "page_size" }`.

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

Клиенты должны читать `detail.error.message` (и учитывать SlowAPI rate-limit ответы).

## Версионирование

Текущий контракт — **v1**. Ломающие изменения без миграции клиентов не допускаются; при необходимости — новый prefix или совместимые поля.
