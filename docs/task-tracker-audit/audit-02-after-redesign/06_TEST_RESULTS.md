# 06. Результаты проверки (audit-02)

Дата: 2026-10-28  
Окружение: `track-db-1` healthy · backend `:8000` · frontend `:3000`  
Учётки: `admin@example.com` / `ChangeMeAdmin123!` · `member@example.com` / `Member123!`

Код приложения **не изменялся** во время аудита.

## 1. Инфра

| Проверка | Результат |
|----------|-----------|
| `GET /health` | 200 `{"status":"ok"}` |
| Frontend | отвечает (307 → app) |
| Postgres Docker | `track-db-1` Up (healthy) |

## 2. API сценарии

| Сценарий | Результат |
|----------|-----------|
| Login admin | 200 + cookies |
| Login member | 200 |
| `GET /api/v1/projects` | 200, 4 проекта, progress |
| `GET /api/v1/tasks?limit=100` | 200, **18** задач |
| Фильтр `project_id=Backend API` | 7 задач, 4 статуса проекта |
| `GET /api/v1/tasks/{id}` | 200, wrapper `{task}` |
| Checklist / assignees / labels в detail | присутствуют на «Push-уведомления» |
| `GET …/comments` | 200, комментарий «Жду ключи» |
| `POST …/move` (status_id+position) | 200; **nested status stale** (см. ниже) |
| Повторный GET после move | nested status корректный; `closed_at` ок |
| Reopen move | `closed_at=null`; nested снова stale в ответе move |
| `GET /api/v1/reports` | 200; metrics ok; **by_status не агрегирован** |
| `GET /api/v1/reports/export` | 200 xlsx ~12660 B |
| `GET /api/v1/notifications` (member) | 1 mention |
| Member `GET /api/v1/admin/users` | **403** |
| seed-demo повтор | идемпотентен (0 новых) — из предыдущего прогона сессии |

### Move — зафиксированный баг

```
MOVE   status_id=Готово     nested=К выполнению  closed_at=set
GET    status_id=Готово     nested=Готово        closed_at=set
REOPEN status_id=К выполнению nested=Готово      closed_at=null
GET    status_id=К выполнению nested=К выполнению
```

## 3. Браузерные сценарии (admin)

| Экран / действие | Результат | Скрин |
|------------------|-----------|-------|
| Обзор dark/light | Данные, overdue, projects progress | 01, 11 |
| Проекты list | 4 карточки | 02 |
| Kanban Backend API dark/light | Колонки с задачами, overdue red, filters | 03, 10 |
| Task detail dark/light/system | Checklist, comment, meta, actions | 04, 12, 13 |
| Список | 18 строк, статусы/приоритеты/сроки | 05 |
| Мои задачи | Группы сроков + завершённые | 06 |
| Отчёты | Метрики + Excel button; charts слабо | 07 |
| Админка | Users + create form | 08 |
| Inbox | Empty state «Пока тихо» | 09 |
| Тема Светлая/Тёмная/Системная | Переключается через меню | 10–13 |
| Узкий viewport home | Контент читаем, mobile nav слаб | 14 |

### Не автоматизировано в этом прогоне

- Полноценный drag-and-drop жест (drop-on-card reorder) — **не снят**; API move подтверждён.
- WebSocket live invalidate — **не проверен**.
- Полный цикл deactivate user → login fail.
- Создание проекта/участника только через UI (проекты уже seeded).

## 4. Демо-задачи (выборка)

| Задача | Наблюдение |
|--------|------------|
| Просроченный инцидент 500 | overdue в My/Home; due 27.10 |
| Онбординг экраны | overdue |
| Экспорт Excel | «Сегодня» / На проверке |
| Push-уведомления | В работе, checklist 1/3, comment |
| Авторизация по биометрии / Деплой / Bootstrap admin | Готово |
| Audit2 smoke create / Browser smoke | артефакты проверки |

## 5. Сравнение с audit-01 test evidence

| audit-01 | audit-02 |
|----------|----------|
| [01-board-empty-statuses-500](../audit-01-initial/screenshots/01-board-empty-statuses-500.png) | [03-kanban-backend-api-dark](screenshots/03-kanban-backend-api-dark.png) |
| [03-list-stuck-loading](../audit-01-initial/screenshots/03-list-stuck-loading.png) | [05-list-dark](screenshots/05-list-dark.png) |
| [04-report-stuck-loading](../audit-01-initial/screenshots/04-report-stuck-loading.png) | [07-report-dark](screenshots/07-report-dark.png) |
| [02-admin-users-ok](../audit-01-initial/screenshots/02-admin-users-ok.png) | [08-admin-dark](screenshots/08-admin-dark.png) (расширен UI) |

## 6. Вердикт тестирования

Регрессия P0 audit-01 **не воспроизводится**. Продукт годен для внутренней демо-демонстрации.  
Блокеры перед production: serializer move, агрегация отчёта, counters, security/deploy hygiene, mobile/DnD e2e.

Полный список хвостов — [05_REMAINING_ISSUES.md](05_REMAINING_ISSUES.md).
