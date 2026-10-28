# AI Project Context — Takt

Точка входа для новых задач. Обновлять краткий статус после крупных этапов.

**Обязательно:** перед работой учитывать `AGENTS.md`, этот файл и релевантный код.

## Что такое Takt

Простой менеджер проектов и задач вокруг **Kanban-доски** (Next.js + FastAPI + PostgreSQL).

После входа — доска последнего доступного проекта (или форма «Создайте первый проект»).  
Демо-проекты (`is_demo=true`) видны только участникам; системный admin не получает к ним автоматический доступ.

Репозиторий: https://github.com/gadzhilaev/takt

## Продуктовая концепция

- Регистрация / вход; приглашения по email и поиск зарегистрированных
- 4 столбца у новых проектов; без «Бэклог» в шаблоне
- Срочность через `priority`; удаление задачи — только автор
- Уведомления in-app + Web Push
- Изолированное демо: `demo@example.com` → проект **«Колледж ДГУ»** (8 demo-staff, `users.is_demo`)

## Backend заметки

- Миграции: `003` invites, `004` push, `005` `projects.is_demo`, `006` `users.is_demo`
- Env: `DEMO_USER_EMAIL`, `DEMO_USER_PASSWORD` (локально, не в git)
- `scripts/setup_demo_workspace.py` — сегрегация demo/E2E
- `scripts/seed_college_demo.py` — идемпотентный сид колледжа (задачи + in-app уведомления, без push)
- `scripts/list_test_tasks.py` — просмотр кандидатов на удаление

## Команды

```bash
docker compose up db -d
cd backend && ./.venv/bin/alembic upgrade head
DEMO_USER_EMAIL=… DEMO_USER_PASSWORD=… ./.venv/bin/python scripts/setup_demo_workspace.py
./.venv/bin/python scripts/seed_college_demo.py
./.venv/bin/pytest
cd frontend && npm test && npm run lint && npm run build
# E2E использует DEMO_* / credentials file
PW_CHANNEL=chrome npm run test:e2e
```

## Статус (обновлено 2026-10-28)

Демо-доска «Колледж ДГУ»: 8 demo-профилей сотрудников, ~23 задачи, in-app уведомления.  
E2E в `[E2E] Playwright`. Рабочее «Общее» без tech-мусора. Commit/push/deploy только по разрешению.
