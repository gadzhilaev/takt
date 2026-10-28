# 01. Текущее состояние системы

Дата аудита: 2026-10-28  
Стек: FastAPI + SQLAlchemy 2 async + PostgreSQL 16 + Next.js 14 App Router + TanStack Query + dnd-kit  
Окружение проверки: локальный `uvicorn :8000`, `next dev :3000`, Docker Postgres `:5433`

## 1. Назначение продукта

Командный трекер задач без публичной регистрации: admin создаёт пользователей, команда работает с одной общей доской статусов. Есть Kanban, список, «мои задачи», отчёты/Excel, админка пользователей и настроек команды.

## 2. Карта репозитория

| Путь | Роль |
|------|------|
| `backend/app/models/` | ORM: User, Task, Status, Label, Comment, Checklist, Attachment, ActivityLog |
| `backend/app/api/v1/` | REST `/api/v1/*`, WebSocket `/ws` |
| `backend/app/services/` | auth, tasks, reports, bootstrap, seed, websocket hub |
| `frontend/src/app/` | маршруты: login, board, list, my, report, profile, admin |
| `frontend/src/components/` | shell, kanban, task card/drawer, UI primitives |
| `deploy/` | Caddy reverse proxy |
| `docker-compose.yml` | db + backend + frontend + proxy |

**Проектов / нескольких досок / workspace в модели нет.** Есть только `TeamSettings` (одна запись) и глобальные `statuses`.

## 3. Что реализовано и работает (подтверждено)

### Auth / Admin

- JWT в httpOnly cookies (`access_token`, `refresh_token`) + CSRF cookie/header — `backend/app/api/v1/auth.py`, `deps.py`
- Роли `admin` / `member`, `must_change_password`, deactivate/activate
- Создание пользователей в UI админки — **проверено в браузере** (`/admin`), API `GET /api/v1/admin/users` → 200
- Смена имени/пароля в профиле (код UI: `frontend/src/app/(app)/profile/page.tsx`)
- Rate limit / lockout на логин (`auth_service`, SlowAPI)

### Модель задач (backend)

Полная схема в `backend/app/models/task.py` и `team.py`:

- title, description, status, priority (`low|medium|high|urgent`), due_date, closed_at, position (float)
- assignees (M2M), labels (M2M), checklist_items, comments (+ mentions JSON), activity_log
- soft delete (`deleted_at`)
- Attachment **таблица есть**, API загрузки вложений задач **отсутствует**

### API задач (код существует)

`backend/app/api/v1/tasks.py`: list/create/get/patch/move/delete, comments, activity, checklist add/update.  
Фильтры list: search, status, priority, assignee, label, mine, pagination.

### Frontend каркас

- Навигация: Доска / Список / Мои / Отчёт / Профиль / Админка — `app-shell.tsx`
- Kanban + dnd-kit + quick-add + hotkey `C` — `kanban-board.tsx`
- Карточка: приоритет, срок, labels, avatars, checklist count — `task-card.tsx`
- Drawer: title (debounce), description, status, priority — `task-drawer.tsx`
- Dark/light theme (`next-themes`)

### Инфра

- Alembic миграция `001_initial`
- Bootstrap статусов и admin — `bootstrap.py`
- Demo seed — `seed.py` (member@example.com, 2 демо-задачи)
- Health `GET /health` → ok

## 4. Что реализовано частично

| Область | Backend | Frontend | Комментарий |
|---------|---------|----------|-------------|
| Статусы | CRUD API | только read-only список в admin settings | UI: «редактирование через API» |
| Labels / assignees / due_date | в create/patch | не редактируются в drawer | карточка показывает, drawer — нет |
| Comments / mentions | API есть | UI нет | mentions не порождают уведомлений |
| Checklist | API add/patch | только счётчик на карточке | нет UI редактирования |
| Activity | API есть | UI нет | |
| Soft delete | API delete | UI удаления нет | restore API нет |
| Attachments | модель | нет upload/download API задач | только avatar/logo files |
| WebSocket | broadcast событий | invalidate queries | **без auth** на `/ws` |
| Поиск/фильтры | query params | UI фильтров на доске/списке нет | |
| Отчёты | сервис + Excel | страница есть | **оба endpoint сейчас 500** (см. ниже) |
| DnD порядок | move + position | drop только в колонку, всегда в конец | нет drop-on-card reorder |

## 5. Сломано (подтверждено practically + по логам)

### P0: сериализация `StatusOut` ломает доску и задачи

`StatusOut.id: str` + `model_validate(ORM)` при `UUID` → Pydantic ValidationError  
Файлы: `backend/app/schemas/task.py`, `settings.py:52`, `serializers.py:33`

**Проверено:**

- `GET /api/v1/settings/statuses` → 500
- `GET /api/v1/tasks` → 500
- `POST /api/v1/tasks` коммитит задачу в БД, затем падает на `task_to_out` → клиент видит ошибку, данные остаются («Audit test» появился в `tasks`)
- UI `/board`: пустой экран без колонок — `screenshots/01-board-empty-statuses-500.png`
- UI `/list`: зависает на «Загрузка…» — `screenshots/03-list-stuck-loading.png`

### P0: отчёты

- `GET /api/v1/reports` → 500: `GroupingError` в `closed_by_day` (`report_service.py` + date_trunc/GROUP BY)
- `GET /api/v1/reports/export` → 500: `UnicodeEncodeError` в `Content-Disposition` с кириллическим filename (`reports.py`)
- UI `/report`: вечный «Загрузка отчёта…» — `screenshots/04-report-stuck-loading.png`

### Frontend error UX

Страницы list/report/board при ошибке API не показывают error state (report: `if (isLoading \|\| !data) return loading` — навсегда).

## 6. Архитектурный снимок

```text
Browser → Next.js (:3000) ──rewrite──► FastAPI (:8000)
                │                         │
                │ WS /ws                  │ cookies JWT + CSRF
                └─────────────────────────┘
                                          │
                                     PostgreSQL (:5433)
```

- Бизнес-логика в основном в route handlers + тонкий `task_service` (смешение слоёв).
- Одна «команда» = весь инстанс; нет multi-tenant / project scope.
- Права: почти всё доступно любому активному пользователю; delete — автор или admin.

## 7. Тесты

`backend/tests/`: `test_auth.py`, `test_tasks.py` (closed_at + excel export).  
Покрытие узкое; сериализация StatusOut и reports GROUP BY **не пойманы** текущими тестами (или тесты гонялись на другом pydantic/окружении).

## 8. Оценка зрелости

| Слой | Оценка | Пояснение |
|------|--------|-----------|
| Auth/admin foundation | 7/10 | солидный каркас |
| Task domain model | 7/10 | богатая схема |
| Task API surface | 6/10 | много endpoints, хрупкая сериализация |
| Frontend product UX | 3/10 | skeleton UI, drawer урезан |
| Reliability (сейчас) | 2/10 | core flows 500 |
| Projects / multi-board | 0/10 | нет |

**Итог:** это MVP-каркас с хорошим фундаментом auth и модели данных, но **не usable** как трекер до фикса P0 сериализации/отчётов и доведения карточки задачи в UI.
