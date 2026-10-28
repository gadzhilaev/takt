# 02. Функциональный аудит (после redesign)

Легенда: **работает** / **частично** / **сломана** / **отсутствует**  
Доказательство: `runtime` = API/браузер 2026-10-28; `код` = только по коду (не засчитано как работающее).

Сравнение с [audit-01](../audit-01-initial/02_FUNCTIONAL_AUDIT.md) — колонка «Было».

---

## 1. Управление задачами

| Функция | Было (audit-01) | Сейчас | Доказательство |
|---------|-----------------|--------|----------------|
| Создание | сломана (500) | **работает** | Browser quick-add / smoke `Audit2 smoke create`; list total 18 |
| Редактирование title/desc/status/priority | частично (drawer) | **работает** | `/tasks/{id}` PATCH через UI поля; API |
| Assignees / due / labels | API only | **работает** | Task page listbox/date/tags; API detail |
| Удаление soft | API, UI нет | **работает** | Кнопка «Удалить» на task page |
| Архив | отсутствовал | **частично** | Кнопка «В архив»; полный archive UX не до аудита deeply |
| Дублирование | отсутствовало | **работает** (UI+API) | Кнопка «Дублировать» → `/tasks/{id}/duplicate` |
| Deep link | отсутствовал | **работает** | `/tasks/{uuid}` открывается с данными |
| Чеклисты | API, UI счётчик | **работает** | UI add + toggle на task page; API items |
| Подзадачи | отсутствовали | **частично** | UI create/list; демо-seed почти без subtasks |
| Комментарии | API, UI нет | **работает** | UI list/create; mention → notification у member |
| Упоминания / inbox | не работали | **частично** | Member: 1 notif; admin inbox пуст; WS не перепроверялся end-to-end |
| История | API, UI нет | **работает** | Блок «История» на task page |
| Вложения файлов | модель без API | **отсутствует** | upload task attachments не найден в OpenAPI |
| Приоритеты / сроки | частично | **работает** | Board badges, overdue red, filters |
| Завершение (Готово) | через statuses 500 | **работает** | Move to Готово ставит `closed_at`; reopen сбрасывает |
| Move response nested status | — | **сломана** (частично) | `status_id` ок, `status.name` stale до GET (см. §7) |

---

## 2. Проекты и доски

| Функция | Было | Сейчас | Доказательство |
|---------|------|--------|----------------|
| Проекты | отсутствовали | **работает** | `GET /api/v1/projects` 4 items; UI `/projects` + sidebar |
| Per-project statuses | глобальные + 500 | **работает** | Разные status UUID на проекты с одинаковыми именами |
| Kanban | пустой | **работает** | Backend API: колонки с карточками, фильтры priority/assignee |
| Progress | нет | **работает** | `progress.percent` в API + home cards |
| Участники проекта | нет | **частично** | Members в API project; отдельный UI управления ролями проекта слабый/не проверялся глубоко |
| Архив проекта | — | **не проверена** runtime | |

---

## 3. Навигация и представления

| Экран | Было | Сейчас |
|-------|------|--------|
| Обзор `/home` | не было / board-centric | **работает** — [11-home-light](screenshots/11-home-light.png), [01-home-dark](screenshots/01-home-dark.png) |
| Проекты | нет | **работает** — [02-projects-list-dark](screenshots/02-projects-list-dark.png) |
| Kanban | 500/пусто | **работает** — [03](screenshots/03-kanban-backend-api-dark.png), [10](screenshots/10-kanban-backend-light.png) |
| Список | stuck loading | **работает** — [05-list-dark](screenshots/05-list-dark.png) |
| Мои задачи | код есть | **работает** группировка — [06-my-tasks-dark](screenshots/06-my-tasks-dark.png) |
| Отчёты | 500 / stuck | **работает** с оговорками charts/by_status — [07-report-dark](screenshots/07-report-dark.png) |
| Inbox | нет | **частично** UI empty state — [09-inbox-dark](screenshots/09-inbox-dark.png) |
| Админка | OK | **работает** — [08-admin-dark](screenshots/08-admin-dark.png) |
| Task detail | drawer only | **работает** — [04](screenshots/04-task-detail-dark.png), [12](screenshots/12-task-detail-light.png) |

---

## 4. Отчёты и экспорт

| Функция | Статус | Факт |
|---------|--------|------|
| `GET /api/v1/reports` | **работает** | created=18, closed=3, in_progress=15, overdue=3 |
| by_employee | **работает** | Анна / Иван / Админ счётчики согласованы с UI |
| Excel export | **работает** | 200, xlsx ~12660 bytes |
| by_status aggregation | **сломана** | массив дублирующих пар `['К выполнению',1],…` вместо сумм |
| Charts UI | **частично** | «Закрыто по дням» / «По статусам» визуально почти пустые при наличии closed_by_day |
| on_time_pct | **частично** | везде 0% — либо данные, либо формула; не доказано как «ок» |

---

## 5. Auth / права

| Функция | Статус | Факт |
|---------|--------|------|
| Admin login | **работает** | cookie session в браузере |
| Member login | **работает** | API `Member123!` |
| Member admin deny | **работает** | 403 на `/api/v1/admin/users` |
| Deactivate user UI | **частично** | кнопка есть; полный сценарий disable→login fail не прогонялся в этом аудите |
| CSV import / reset password UI | **частично/отсутствует** | как в audit-01: API шире UI |

---

## 6. Realtime / поиск / фильтры

| Функция | Статус | Комментарий |
|---------|--------|-------------|
| Глобальный поиск topbar | **частично** | поле есть; полный сценарий results не снимался скрином |
| Фильтры на доске | **работает** | priority + assignee combobox |
| List search/sort | **работает** | UI «По обновлению» + search |
| WebSocket auth | **не проверена** в этом прогоне | в redesign заявлялась — без live WS-теста не засчитываем |

---

## 7. Подтверждённый дефект move serializer

```text
BEFORE  status_id=todo   nested=К выполнению
MOVE    status_id=done   nested=К выполнению   closed_at=SET   ← nested stale
GET     status_id=done   nested=Готово         closed_at=SET   ← OK
REOPEN  status_id=todo   nested=Готово         closed_at=null  ← nested stale
GET     status_id=todo   nested=К выполнению                 ← OK
```

Итог: персист верный; optimistic/клиент, доверяющий nested `status` из ответа move, может показать чужую колонку до refetch.

---

## 8. Итог функциональности

P0 блокеры audit-01 **сняты**. Ядро task/project workflow **используемо**. Перед production нужны фиксы §7, агрегации отчёта, вложений (если в scope), hardening адаптивности и проверка WS/DnD reorder end-to-end (см. [06_TEST_RESULTS.md](06_TEST_RESULTS.md)).
