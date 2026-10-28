# 05. Оставшиеся проблемы и пробелы

Структура сравнения: что было → что исправлено → что ещё плохо → что отсутствует → pre-production.

## 1. Что было в первом аудите (критичное)

Из [audit-01](../audit-01-initial/):

- `GET` statuses / сериализация задач → **500** → пустая доска
- List и Report UI зависали на загрузке (те же 500)
- Excel/reports backend 500
- Dark theme фактически не работал
- Нет проектов / multi-board
- Нет UI комментариев, чеклистов, assignees, due в карточке, deep link
- DnD только «в конец колонки»
- Attachments / subtasks / notifications — отсутствовали или не работали

## 2. Что исправлено и подтверждено проверкой

| Проблема audit-01 | Статус audit-02 |
|-------------------|-----------------|
| Statuses/tasks 500 | **Исправлено** — list/board/API 200, данные на экране |
| Report/Excel 500 | **Исправлено** — report JSON + xlsx 200 |
| Пустая доска | **Исправлено** — demo + projects Kanban заполнены |
| Нет проектов | **Исправлено** — 4 проекта, progress |
| Dark mode | **Исправлено** — light/dark/system переключаются |
| Нет task URL / rich card | **Исправлено** — `/tasks/{id}` с checklist/comments/history/meta |
| Нет UI assignees/due/labels | **Исправлено** на task page |
| Notifications/mentions | **Частично исправлено** — API notif у member после mention |

## 3. Реализовано, но работает неправильно

1. **Move response: stale nested `status`** — `status_id`/`closed_at` верные, `status.name` из предыдущего состояния до отдельного GET. Риск для optimistic UI.
2. **`metrics.by_status` в отчёте** — не агрегирован (повторяющиеся имена статусов с count=1).
3. **`comment_count` в list** — может быть 0 при живых комментариях в detail (пример: «Push-уведомления»).
4. **Charts на `/report`** — UI почти пустой при наличии `closed_by_day` и задач.
5. **`on_time_pct` = 0** у всех сотрудников — подозрительно; не доказано корректным.
6. **Light theme surfaces** — тёмные inputs/cards на светлом фоне выглядят как баг темы.
7. **Checklist controls** — a11y snapshot `readonly` на checkbox (подозрение на нестандартный toggle).

## 4. Проблемы, проявившиеся после переработки

- Per-project статусы с одинаковыми именами → клиенты обязаны слать status_id **своего** проекта (иначе 422/неверная колонка).
- Больше экранов → слабый mobile shell (sidebar desktop-first).
- Inbox у admin пуст при активных mention у других — ожидаемо, но легко принять за «уведомления не работают».
- Demo + smoke задачи смешаны (Audit2 / Browser smoke) — шум в демо для заказчика.

## 5. Что ещё улучшить в UX/UI

См. также [03_UX_UI_AUDIT.md](03_UX_UI_AUDIT.md):

- Согласовать light/dark token surfaces
- Mobile navigation + Kanban
- Chart rendering и легенды приоритетов
- Toasts/ошибки сети, skeleton единообразие
- Project members/settings UI
- Discoverability hotkey `C`

## 6. Какие функции отсутствуют (scope)

| Функция | Статус |
|---------|--------|
| Вложения файлов к задаче (upload/download) | отсутствует как фича (модель могла остаться) |
| Полноценный project RBAC UI | слабо / не подтверждено |
| Повторяющиеся задачи | отсутствует |
| Шаблоны проектов/задач | отсутствует |
| Restore после soft delete | не подтверждено |
| CSV import / reset password в UI | API шире UI (как audit-01) |
| Публичная регистрация | out of scope (by design) |
| Полноценный E2E DnD reorder proof в этом аудите | не зафиксирован скрином/логом жеста |

## 7. Что исправить перед production

**Must**

1. Починить serializer ответа `POST /tasks/{id}/move` (актуальный nested `status`).
2. Агрегировать `by_status` в reports (+ связать charts).
3. Синхронизировать `comment_count` (и подобные counters) с фактом.
4. Пройти security checklist: SECRET_KEY, ADMIN_PASSWORD, CORS, HTTPS, WS auth — по [audit-01 architecture](../audit-01-initial/05_ARCHITECTURE.md) + текущий deploy.
5. Регрессионные тесты на former P0 (statuses/tasks/reports serialization).

**Should**

6. Light theme polish; mobile shell.
7. Подтвердить DnD reorder (drop-on-card) браузером + e2e.
8. Решить scope вложений или убрать мёртвую модель из ожиданий.
9. Проверить формулу `on_time_pct`.
10. Очистить/пометить smoke-задачи в демо.

**Nice**

11. Project settings UI, richer activity types, empty-state copy для inbox.
