# План кроссплатформенных клиентов (Flutter)

Backend Takt остаётся **единым источником данных**. Клиенты: Web (текущий Next.js), затем Flutter iOS / Android / Windows / macOS.

## 1. Что уже подходит для клиентов

| Область | API | Заметки |
|---------|-----|---------|
| Auth | `POST /api/v1/auth/login`, refresh, logout, `GET /me` | Cookie+CSRF удобны для web; для Flutter нужен **token mode** (см. §2) |
| Задачи | CRUD, move, comments, checklist, activity, duplicate | Пагинация `page` / `page_size` |
| Проекты | list/create/get + members | Progress в ответе |
| Статусы | `/api/v1/settings/statuses?project_id=` | Per-project |
| Отчёты | `/api/v1/reports`, export xlsx | |
| Уведомления | list / read / read-all | |
| Пользователи | `/api/v1/users`, admin users | RBAC admin/member |
| Realtime | WebSocket `/ws` | Нужна явная auth для native |
| Файлы | avatar/logo сейчас | Task attachments — backlog |

## 2. Доработки API перед Flutter (без реализации в этой задаче)

1. **Bearer access + refresh tokens** (или dual-mode: cookies для web, Authorization header для native).
2. **CSRF** только для cookie-сессий; native с Bearer без CSRF.
3. **WebSocket auth**: query token или first-message auth; отклонять анонимов.
4. **Единый error envelope** `{ error: { code, message } }` — уже частично есть; зафиксировать контракт.
5. **Upload/download вложений** задач: multipart + signed URLs.
6. **OpenAPI** как контракт для codegen (`openapi-generator` / `chopper` / `retrofit`).
7. **Idempotency-Key** на create/move для нестабильных сетей.
8. **ETag / If-None-Match** или `updated_since` для синка офлайн-кэша.

## 3. Архитектура Flutter-клиентов

```
apps/
  track_mobile/     # iOS + Android (одна кодовая база)
  track_desktop/    # Windows + macOS (shared packages)
packages/
  track_api/        # OpenAPI client, auth, models
  track_domain/     # use-cases, repositories
  track_ui/         # design tokens (те же semantic colors, что web)
```

- Состояние: Riverpod или Bloc.
- Локальный кэш: Drift/Isar + outbox для offline create/move.
- Пуши: FCM/APNs → deep link `/tasks/{id}`.
- Дизайн: те же UX-принципы (простые подписи, крупные hit-targets), не копия YouGile.

## 4. Этапы

| Этап | Результат |
|------|-----------|
| A | Dual auth + WS auth + OpenAPI freeze |
| B | Flutter mobile MVP: login, Мои, доска проекта, карточка, статус/срок/исполнитель |
| C | Уведомления + offline outbox |
| D | Desktop shell (windowing, keyboard shortcuts) |
| E | Вложения и richer reports |

## 5. Не делать сейчас

- Не форкать бизнес-логику в клиент.
- Не плодить отдельные «mobile API».
- Не начинать Flutter-приложение до этапа A.
