# 05. Архитектура и безопасность

## 1. Текущая архитектура (as-is)

```text
Next.js (BFF rewrites) ──► FastAPI routers ──► SQLAlchemy models
         │                      │
         │                 services/* (тонкие)
         │                      │
         └──── WebSocket hub ◄──┘ (broadcast dicts)
```

**Сильные стороны (сохранить)**

- Cookie JWT + CSRF для browser SPA
- Async SQLAlchemy + Alembic
- Soft delete, float positions, activity log
- Separation frontend/backend в monorepo
- Next rewrites для same-origin API (упрощает cookies)

**Слабые стороны**

| Проблема | Где | Риск |
|----------|-----|------|
| Толстые route handlers | `tasks.py`, `admin.py` | сложнее тестировать/переиспользовать |
| Сериализация ad-hoc | `StatusOut.model_validate` vs ручной `str(id)` | **уже прод-блокер** |
| Нет project scope | все tasks глобальны | нельзя вырастить продукт |
| WS без auth | `ws.py` | утечка событий любому клиенту |
| Files без auth | `files.py` avatars/logo | IDOR на файлы |
| Attachment dead code | model only | drift схемы |
| page_size до 1000/10000 | list/export | perf при росте |
| Concurrent edits | last-write-wins | потеря данных |
| Frontend state | Query invalidate на каждый WS event | лишние full refetch |
| Error handler глотает детали | `main.py` DEBUG=false | сложно диагностировать в UI |

## 2. Рекомендуемая целевая архитектура (to-be)

### Backend

```text
api/v1/          # тонкие handlers: authz → service → schema
domain/services/ # TaskService, ProjectService, NotificationService
schemas/         # Pydantic v2 с field_validator / Annotated UUID→str
repositories/    # опционально позже; не обязательно сейчас
```

Правила:

1. **Единый serializer** для Status/Task/Checklist: всегда `id: UUID` в schema **или** явный `str()` helper — не смешивать.
2. Любая мутация задач: service method + activity + ws event в одном месте.
3. **Authz helper**: `ensure_project_access(user, project_id, min_role)`.
4. Транзакции: create/update не оставляют «успешный commit + failed response» — сериализация до commit или rollback on serialize fail (лучше serialize after commit но из уже загруженных Python-объектов без ValidationError).

### Frontend

```text
features/tasks/     board, drawer/page, api hooks
features/projects/
features/inbox/
shared/ui/          button, input, select, dialog, toast, empty, error
shared/api/         api client + error types
```

- Task detail = **route** `/tasks/[id]` (+ optional parallel drawer)
- Optimistic updates для move/create
- WS: точечный cache update вместо blind invalidate (P1)

### Не переписывать

- Auth cookies/CSRF
- Alembic процесс
- dnd-kit / TanStack Query / Next App Router
- Admin users flow

## 3. API-контракты (изменения)

### Срочный hotfix (без смены URL)

- Починить `StatusOut` / `ChecklistItemOut` / nested status в `TaskOut`
- Починить `closed_by_day` (label/GROUP BY 1 или `.label()`)
- RFC5987 filename для Excel (`filename*=UTF-8''...`)

### Следующий контрактный слой

```http
POST   /api/v1/projects
GET    /api/v1/projects/:id/tasks
POST   /api/v1/tasks                    # + project_id
GET    /api/v1/tasks/:id                # уже есть
POST   /api/v1/tasks/:id/attachments
GET    /api/v1/notifications
PATCH  /api/v1/notifications/:id/read
```

Обратная совместимость: `/api/v1/tasks` без project → default project.

## 4. Данные и производительность

| Тема | Рекомендация |
|------|--------------|
| Пагинация | default 50; board грузит per-status или cursor; убрать page_size=1000 из FE |
| Индексы | уже есть status+position, due, deleted; добавить `(project_id, status_id, position)` |
| N+1 | selectinload уже используется — сохранить |
| DnD order | fractional indexing оставить; считать position между neighbors |
| Export | stream/background job при >5k rows (P2) |
| Search | ILIKE ок до ~10k; позже pg_trgm |

## 5. Конкурентность

- Move: optimistic FE + server returns canonical task; conflict rare с float gaps
- Optional `updated_at` If-Match / version column для detail PATCH (P1)
- Comments: append-only — ок

## 6. Безопасность

### Подтверждено / по коду

| Issue | Severity | Файл | Fix |
|-------|----------|------|-----|
| WS без auth | High | `ws.py` | принимать cookie/JWT на connect; подписка на project |
| Avatar/logo public | Medium | `files.py` | require auth (или signed URLs) |
| Attachment path traversal | N/A пока нет upload | — | при реализации: uuid stored_name, allowlist MIME, size limit |
| CSRF | ok | deps | сохранить |
| Password hashing | ok | argon2 | сохранить |
| Login rate limit | ok | | сохранить |
| Soft delete authz | ok-ish | author/admin | добавить project role later |
| Description HTML | Low now | FE plain | если markdown/HTML — sanitize (DOMPurify) |
| Unhandled 500 hides cause | Medium ops | main.py | structured logging + request id |
| Avatar MIME not validated | Medium | users.py upload | allowlist image/* + magic bytes |
| Login lockout in-memory | Low–Med | auth_service | Redis/DB при multi-worker |
| WS hub in-memory | Low–Med | websocket_hub | Redis pub/sub при scale-out |
| Password needs_rehash ignored | Low | security.py | rehash on login |
| Alembic `001` = `create_all` | Med ops | alembic/versions | дальше — инкрементальные revision |

### IDOR

Сейчас любой member видит все tasks команды — by design single-tenant.  
После Projects: обязательно фильтр `project_id` + membership, иначе классический IDOR.

## 7. Миграция существующих данных

Безопасно и обратимо:

1. Создать таблицу `projects`, запись `Общее` (`is_default`)
2. `ALTER tasks ADD project_id NULL` → backfill → NOT NULL
3. Скопировать global `statuses` в project statuses **или** сначала оставить global statuses с `project_id NULL` meaning default
4. Labels: оставить global на этапе 1
5. Не удалять soft-deleted

Рекомендуемый путь статусов: **per-project statuses** с копией из template при создании проекта; default project получает текущие 5 статусов as-is.

## 8. Observability

Добавить (P1):

- request_id middleware
- логирование ValidationError/SQL errors в logger (не в клиент)
- healthcheck DB dependency
- FE: Sentry или хотя бы toast + console correlation id
