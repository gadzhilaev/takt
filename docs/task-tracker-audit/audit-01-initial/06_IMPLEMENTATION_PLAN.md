# 06. План внедрения

Приоритеты: **P0** блокер usable / data integrity · **P1** must-have продукта · **P2** усиление  
Сложность: S ≤1д · M 2–4д · L 1–2нед · XL >2нед

---

## Phase 0 — Сделать трекер снова рабочим (P0)

| ID | Задача | Зависимости | Сложность | DoD |
|----|--------|-------------|-----------|-----|
| P0-1 | Починить сериализацию UUID→str для StatusOut / ChecklistItemOut / nested status | — | S | `GET /statuses`, `GET /tasks` 200; pytest green |
| P0-2 | Убрать commit-before-serialize failure mode (create/update возвращают 200) | P0-1 | S | POST task → 200 + id; нет «тихих» orphan при serialize fail |
| P0-3 | Починить `closed_by_day` GROUP BY | — | S | `GET /reports` 200 |
| P0-4 | Excel `Content-Disposition` ASCII/`filename*` | — | S | export 200, файл открывается |
| P0-5 | FE error/empty states на board/list/my/report | P0-1 | S | при 500 виден текст ошибки + retry; при [] — CTA |
| P0-6 | `darkMode: "class"` в Tailwind + проверка theme toggle | — | S | ручной toggle реально меняет тему |
| P0-7 | Smoke E2E вручную: login → create → drag → open drawer → patch | P0-1..5 | S | чеклист пройден |

**Выход Phase 0:** демо-задачи видны на доске; create/move работают; отчёт открывается; theme toggle работает.

---

## Phase 1 — Полноценная карточка задачи (P0/P1)

| ID | Задача | Deps | Сложность | DoD |
|----|--------|------|-----------|-----|
| P1-1 | Route `/tasks/[id]` (+ optional drawer shell) | P0 | M | URL шарится, refresh сохраняет контекст |
| P1-2 | UI: assignees, due, labels, priority, status | P1-1 | M | все поля PATCH через UI |
| P1-3 | UI: comments list+create | P1-1 | M | комментарий виден после reload |
| P1-4 | UI: checklist add/toggle | P1-1 | S | счётчик на карточке обновляется |
| P1-5 | UI: activity timeline | P1-1 | S | события created/moved/updated |
| P1-6 | Delete/archive в UI + confirm | P0 | S | soft delete; скрытие с доски |
| P1-7 | List/My клик → task route | P1-1 | S | |
| P1-8 | DnD reorder внутри колонки | P0 | M | drop на карточку считает mid position |

**Выход:** задача редактируется без Postman; deep link работает.

---

## Phase 2 — Продуктивность доски (P1)

| ID | Задача | Deps | Сложность | DoD |
|----|--------|------|-----------|-----|
| P2-1 | Поиск + фильтры (status/priority/assignee/label/due) на board/list | P0 | M | URL query sync |
| P2-2 | Quick create с assignee/priority (popover) | P1-2 | S | |
| P2-3 | Toast/saved indicator + API error mapping | P0-5 | S | |
| P2-4 | Hotkeys: `C`, `Esc`, `/` focus search | P2-1 | S | documented in UI |
| P2-5 | WS auth + subscribe | — | M | неавторизованный WS reject |
| P2-6 | Optimistic move + точечный cache update | P2-5 | M | меньше full refetch |
| P2-7 | Files auth для avatars | — | S | 401 без cookie |

---

## Phase 3 — Projects (P1 product leap)

| ID | Задача | Deps | Сложность | DoD |
|----|--------|------|-----------|-----|
| P3-1 | Миграция Project + default «Общее» + backfill tasks | Phase1 | L | zero data loss |
| P3-2 | API projects CRUD + membership | P3-1 | M | |
| P3-3 | Statuses per project (copy template) | P3-1 | M | |
| P3-4 | FE `/projects`, project board replaces global board | P3-2 | L | |
| P3-5 | Authz: task access via project membership | P3-2 | M | IDOR tests |
| P3-6 | Reports filter by project | P3-1 | M | |

---

## Phase 4 — Командная работа (P1/P2)

| ID | Задача | Deps | Сложность | DoD |
|----|--------|------|-----------|-----|
| P4-1 | Notification model + create on assign/mention/comment | P1-3, P1-2 | M | |
| P4-2 | Inbox UI `/inbox` | P4-1 | M | |
| P4-3 | Attachments upload/download (secure) | P1-1 | M | size/MIME limits, auth |
| P4-4 | Mentions autocomplete `@` | P1-3 | S | |
| P4-5 | Home overview | P3-4 | M | |

---

## Phase 5 — Усиления (P2)

| ID | Задача | Сложность |
|----|--------|-----------|
| P5-1 | Saved views / filters | M |
| P5-2 | Bulk actions на list | M |
| P5-3 | Duplicate task | S |
| P5-4 | Command palette | M |
| P5-5 | Calendar view | L |
| P5-6 | GitHub issue URL field / later webhook | M–L |
| P5-7 | Task `version` / If-Match | M |
| P5-8 | Restore deleted / trash UI | M |

---

## Порядок работ (рекомендуемый)

```text
Week 1:     P0-1 … P0-7
Week 2–3:   P1-1 … P1-8
Week 4:     P2-1 … P2-7
Week 5–7:   P3-1 … P3-6
Week 8–9:   P4-1 … P4-5
Later:      Phase 5 by demand
```

Параллелить можно: FE empty states (P0-5) || backend report fixes (P0-3/4).

---

## Что сохранить обязательно

- Cookie auth + CSRF
- Admin create user + temp password + must_change_password
- Soft delete + activity log schema
- Float position indexing
- Demo seed / bootstrap statuses
- Report KPI concept (после фикса SQL)

## Риски

| Риск | Митигация |
|------|-----------|
| Projects migration ломает FE routes | feature flag; default project aliases `/board` |
| Scope creep GitHub | не начинать до Phase 4 |
| Rewrite UI kit | добавлять компоненты точечно |
| Тесты pytest на sqlite vs PG GROUP BY | гонять reports tests на Postgres |
