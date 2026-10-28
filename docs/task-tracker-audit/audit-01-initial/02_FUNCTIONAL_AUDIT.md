# 02. Функциональный аудит

Легенда статуса: **работает** / **частично** / **отсутствует** / **сломана** / **не проверена**  
Тип: `код` = только по коду; `runtime` = API/браузер 2026-10-28.

---

## 1. Управление задачами

| Функция | Статус | Доказательство |
|---------|--------|----------------|
| Создание | **сломана** (runtime) / код есть | `POST /tasks` пишет в БД, ответ 500 (`serializers.task_to_out` → StatusOut). UI quick-add не может завершиться пока statuses 500. |
| Редактирование title/desc/status/priority | **частично** | Drawer: `task-drawer.tsx`. Assignees/labels/due — только API. |
| Удаление (soft) | **частично** | API `DELETE` + `can_delete_task`. UI кнопки удаления нет. Restore нет. |
| Архивирование / восстановление | **отсутствует** | soft delete ≠ archive UX |
| Статусы | **сломана** list + **частично** admin | List 500. Admin settings read-only. CRUD API statuses есть. |
| Приоритеты | **частично** | Backend + drawer select. Нет inline на карточке. |
| Дедлайны | **частично** | Поле/отображение на карточке; в drawer **нет** редактирования. |
| Исполнители | **частично** | M2M + API; UI назначения нет. |
| Метки | **частично** | get_or_create_label; UI нет. |
| Описание | **частично** | textarea; placeholder «HTML», рендера rich-text нет. |
| Чеклисты | **частично** | API; UI только `done/total` на карточке. |
| Подзадачи | **отсутствует** | нет parent_id / subtask model |
| Вложения | **отсутствует** (как фича) | модель `Attachment`, нет upload endpoint |
| Комментарии | **частично** | API list/create; UI нет |
| Упоминания | **частично** | `mention_user_ids` сохраняются JSON; нет нотификаций/парсинга `@` |
| История изменений | **частично** | `ActivityLog` + `GET .../activity`; UI нет |
| Уникальный ID / deep link | **частично** | UUID есть; URL `/task/[id]` / query open — **нет**, только local state drawer |
| Дублирование задачи | **отсутствует** | |
| Повторяющиеся задачи | **отсутствует** | |

---

## 2. Управление проектами

| Функция | Статус | Доказательство |
|---------|--------|----------------|
| Проекты | **отсутствует** | нет entity Project |
| Участники проекта | **отсутствует** | глобальный список users |
| Роли в проекте | **отсутствует** | только global admin/member |
| Несколько досок | **отсутствует** | одна сетка статусов |
| Настраиваемые колонки | **частично** | statuses CRUD API; UI почти нет |
| Шаблоны | **отсутствует** | |
| Прогресс проекта | **отсутствует** | отчёт по команде, не по проекту |
| Настройки команды | **частично** | имя команды работает (`/settings/team` 200); статусы в UI read-only |

**Вывод:** продукт сейчас — **single-team single-board**, не project tracker. Проекты — целевое расширение (см. `04_TARGET_PRODUCT.md`), не «поломка».

---

## 3. Представления

| View | Статус | Нужно ли продукту |
|------|--------|-------------------|
| Kanban | **сломана** runtime / код есть | **Да — primary** |
| Список/таблица | **сломана** runtime / UI read-only | **Да** (после фикса + open task) |
| Мои задачи | **сломана** (тот же `/tasks`) / UI list | **Да** |
| Календарь | **отсутствует** | P2, после due-date UX |
| Timeline/Roadmap | **отсутствует** | не приоритет для MVP команды |
| GitHub-like table board | **отсутствует** | опционально P2 |

---

## 4. Командная работа

| Функция | Статус | Доказательство |
|---------|--------|----------------|
| Комментарии | **частично** (API only) | |
| Упоминания | **частично** (storage only) | |
| Уведомления | **отсутствует** | нет Notification model/UI |
| Совместное редактирование | **отсутствует** | last-write-wins PATCH |
| Realtime updates | **частично** | WS broadcast + invalidate; **WS без auth** (`ws.py`) |
| Журнал активности | **частично** | API; UI нет |
| Admin audit | **частично** | `AdminAuditLog` model + admin actions |

---

## 5. Продуктивность

| Функция | Статус | Доказательство |
|---------|--------|----------------|
| Глобальный поиск | **отсутствует** UI; API search param есть | |
| Фильтры на доске | **отсутствует** UI | |
| Сохранённые фильтры | **отсутствует** | |
| Массовые действия | **отсутствует** | |
| Command palette | **отсутствует** | |
| Горячие клавиши | **частично** | только `C` для quick-add (`kanban-board.tsx`) |
| Excel export | **сломана** | Unicode filename + зависит от list_tasks |

---

## 6. Интеграции

| Интеграция | Статус | Целесообразность |
|------------|--------|------------------|
| GitHub Issues/PR/commits | **отсутствует** | **Не сейчас.** Имеет смысл после стабилизации core и появления Projects. Webhook sync — P2/P3. |
| Incoming webhooks | **отсутствует** | P2 |
| Slack/Telegram | **отсутствует** | после notifications |

---

## 7. Auth / Admin (runtime)

| Сценарий | Статус | Проверка |
|----------|--------|----------|
| Login admin | **работает** | API + браузер → `/board` |
| `/admin` users list | **работает** | screenshot `02-admin-users-ok.png` |
| Create user form | **работает** (UI) | форма рендерится; create не кликали в этом прогоне |
| Deactivate buttons | **не проверена** кликом | код вызывает admin activate/deactivate |
| Team name settings | **частично** | API 200; UI не кликали |
| Force change password flow | **не проверена** | код login → `/change-password` |

---

## 8. Подтверждённые дефекты (не гипотезы)

1. **StatusOut UUID→str** ломает statuses/tasks/create response — `schemas/task.py`, `settings.py`, `serializers.py`
2. **POST create commit-then-fail** — задача остаётся без успешного ответа клиенту — `tasks.py` create + `task_to_out`
3. **closed_by_day GROUP BY** — `report_service.py:107-120` → reports 500
4. **Excel Content-Disposition Cyrillic** — `reports.py` export → 500
5. **UI вечный loading** без error — `list/page.tsx`, `report/page.tsx`
6. **WS без аутентификации** — `api/v1/ws.py`
7. **DnD всегда append** — `kanban-board.tsx` `onDragEnd` считает position как last+1024, drop target только `col-*`
8. **Drawer без assignees/due/labels/comments/checklist/delete** — `task-drawer.tsx` vs API surface
9. **List/My без открытия задачи** — нет onClick → drawer/route
10. **Attachment dead model** — нет API
11. **Theme toggle не связан с Tailwind** — `ThemeProvider attribute="class"`, но в `frontend/tailwind.config.ts` нет `darkMode: "class"` (дефолт `media`) → ручной переключатель темы почти наверняка не управляет `dark:` классами (подтверждено по коду; [frontend explore](91950806-52bd-4398-a644-04dcd16c94a9))
12. **`due_before`/`due_after` в `task_service.list_tasks` не проброшены в route** — фильтр по сроку только через код сервиса ([backend explore](8a6e6e3c-9814-4486-afa9-8551211ef040))
13. **Checklist delete / comment edit-delete** — endpoints отсутствуют (backend explore)
14. **Admin CSV import / reset-password / delete+reassign** — API есть (`admin.py`); UI админки покрывает только create + activate/deactivate

## 9. Гипотезы (не подтверждены runtime)

- Race при одновременном move двух клиентов (position collision) — модель float gap позволяет, conflict resolution нет
- XSS через description HTML, если позже начнут `dangerouslySetInnerHTML` без sanitize — сейчас textarea plain
- IDOR на avatar files (`/files/avatars/{id}` без auth) — по коду похоже, не fuzz'или
- Cookie Secure=false локально ок; prod зависит от `.env`
