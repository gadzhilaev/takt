# 07. Стратегия тестирования

Цель: безопасно внедрять Phase 0–4 без регрессий auth и потери данных.

## 1. Пирамида

| Уровень | Фокус | Инструменты |
|---------|-------|-------------|
| Unit | serializers, position math, authz helpers | pytest |
| API | contracts, CSRF, permissions, reports SQL | httpx AsyncClient + **Postgres** |
| Component | drawer fields, empty/error | React Testing Library (добавить) |
| E2E smoke | login → board → create → move → detail | Playwright (добавить) |
| Manual | DnD feel, mobile, a11y keyboard | чеклист ниже |

Текущие тесты (`test_auth.py`, `test_tasks.py`) недостаточны: не ловят StatusOut UUID и reports GROUP BY.

## 2. Обязательные регрессии перед каждым merge в main

### API (автомат)

1. Login admin / bad password / lockout behavior  
2. CSRF required on mutating routes  
3. `GET /settings/statuses` → 200, `id` string UUID  
4. `GET /tasks` → 200, nested `status.id` string  
5. `POST /tasks` → 200 **и** row exists (не 500 после commit)  
6. `POST /tasks/{id}/move` → status + closed_at rules (уже есть частично)  
7. Soft delete: author ok, other member 403, admin ok  
8. `GET /reports` + export 200 (filename header)  
9. После Projects: task from project A invisible/403 for non-member  

### Frontend smoke (ручной или E2E)

1. Login → board показывает колонки  
2. Quick-add Enter → карточка появляется  
3. Drag в «Готово» → closed визуально/в detail  
4. Open task URL → refresh не теряет задачу  
5. List click → same task  
6. Ошибка API (devtools offline) → error UI, не вечный loading  

## 3. Тесты, которые нужно добавить сразу (Phase 0)

```text
test_serializers_status_out_from_orm
test_list_statuses_ok
test_list_tasks_ok
test_create_task_returns_200
test_closed_by_day_query
test_export_content_disposition_ascii
```

Все — против PostgreSQL (docker), не SQLite: date_trunc/GROUP BY баг проявляется на PG.

## 4. Тесты по фазам

| Phase | Доп. покрытие |
|-------|----------------|
| 1 Task detail | comments CRUD, checklist toggle, activity present, deep link |
| 2 Filters | query params filter matrix; WS rejects anonymous |
| 3 Projects | migration backfill; membership IDOR suite; default project alias |
| 4 Notifications | assign→notification; mention→notification; mark read |
| 5 Attachments | MIME reject, size limit, auth required, path traversal |

## 5. Безопасность (чеклист)

- [ ] WS connect without cookie → close/reject  
- [ ] `/files/avatars/*` without auth → 401 (после фикса)  
- [ ] Upload: `../../` filename stored as uuid only  
- [ ] Member cannot delete чужую задачу  
- [ ] Member cannot admin endpoints  
- [ ] Deactivated user → 401  
- [ ] XSS: description with `<script>` не исполняется (если rich render)  
- [ ] CSRF missing → 403  

## 6. Миграции данных

Для каждой миграции Projects:

1. Backup `pg_dump`  
2. Upgrade на копии prod-like данных  
3. Assert: count(tasks) = count(tasks where project_id = default)  
4. Assert: statuses count per default project = pre-migration global  
5. Rollback script / downgrade проверен на staging  

## 7. Ручной UX чеклист (после Phase 1)

| # | Сценарий | Ожидание |
|---|----------|----------|
| 1 | Новый пользователь, first board | видит empty CTA или демо |
| 2 | Создать задачу ≤3с | успех без перезагрузки |
| 3 | Назначить себя | появляется в «Мои» |
| 4 | Due yesterday | red overdue на карточке |
| 5 | Комментарий | realtime у второго браузера |
| 6 | Mobile width 390 | колонки scroll, drawer fullscreen |
| 7 | Keyboard only | tab login, C create, Esc close |
| 8 | Two users drag same task | последний move побеждает без 500 |

## 8. Definition of Done для production-ready core

- Phase 0–1 закрыты  
- CI: pytest на Postgres + lint ruff  
- E2E smoke в CI (хотя бы 1 happy path)  
- Нет известных P0  
- Backup/restore документирован (уже есть в README)  
- `SEED_DEMO_DATA=false` в prod  

## 9. Что не тестировать избыточно

- Визуальный пиксель-матч с Linear/YouGile  
- Полный load test до появления реальных объёмов  
- GitHub sync до решения о интеграции  
