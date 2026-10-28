# AI Project Context — Takt

Точка входа для новых задач. Обновлять краткий статус после крупных этапов.

**Обязательно:** перед работой учитывать `AGENTS.md`, этот файл и релевантный код. Не начинать с нуля и не повторять завершённые этапы без запроса.

## Что такое Takt

Веб-платформа командных задач и проектов (Next.js + FastAPI + PostgreSQL). Без публичной регистрации. Бренд UI: **Takt** (официальные SVG в `frontend/public/brand/`, акцент `#315F72` / `#366574`).

Репозиторий: https://github.com/gadzhilaev/takt  
Локальный корень: `Documents/Mobile Projects/takt`.

## Что реализовано и проверено

- Auth (cookies/CSRF), admin users, принудительная смена пароля
- Проекты, статусы, права
- Задачи: assignees, due, priority, comments, checklist, subtasks, attachments
- Kanban desktop DnD; mobile одна колонка + tabs/select
- List/my/home, фильтры в URL, отчёты + Recharts + Excel
- Inbox/notifications, WebSocket hub
- UX-полировка (`docs/TRACK_FINAL_POLISH.md`)
- Визуальный ребрендинг + **официальные логотипы** (`docs/TAKT_REBRANDING.md`)
- Тесты: backend pytest, frontend vitest, Playwright core-flow
- Локальная папка `takt`; Docker volume `track_pgdata` через `COMPOSE_PROJECT_NAME=track`

## Завершённые крупные этапы

1. Аудиты 01–03 (`docs/task-tracker-audit/`) — **не перезапускать** без запроса
2. Redesign + projects + demo seed
3. UX/perf audit-03 fixes
4. Final polish (mobile Kanban, charts height, URL filters, create→project)
5. Visual rebrand Track→Takt (UI + tokens)
6. Repo/product rename: GitHub `takt`, docs/AGENTS/Cursor rules, APP_NAME
7. Локальный rename папки + восстановление `.venv` (2026-10-28)
8. Интеграция утверждённых SVG логотипов (symbol / wordmark / logo + on-dark)

## Сейчас / next

- Push накопленных коммитов — только по разрешению
- Deploy — только по разрешению; не трогать production volumes без запроса
- Flutter/desktop клиенты — план (`docs/CROSS_PLATFORM_PLAN.md`), кода клиента нет

## Бренд-ассеты

| Файл | Назначение |
| --- | --- |
| `frontend/public/brand/takt-symbol.svg` | знак; favicon; `BrandMark` |
| `frontend/public/brand/takt-wordmark.svg` | надпись (+ `*-on-dark`) |
| `frontend/public/brand/takt-logo.svg` | полный логотип; sidebar/login (`BrandLogo`) |
| `frontend/public/favicon.svg` | копия знака |

Оригиналы не перерисовывать. On-dark меняет только цвет текста надписи.

## Архитектурные решения

- Единый backend API; Caddy в Docker проксирует `/` и `/api`/`/ws`
- DB/Docker technical names остаются `track*` + `COMPOSE_PROJECT_NAME=track` → volume `track_pgdata`
- Design tokens в CSS variables; shared UI components
- Mobile Kanban без touch-DnD (scroll-first)

## Важные документы

| Документ | Зачем |
| --- | --- |
| `AGENTS.md` | постоянный контекст агентов |
| `docs/TAKT_REBRANDING.md` | визуальный ребрендинг / логотипы |
| `docs/TRACK_FINAL_POLISH.md` | UX-полировка (история) |
| `docs/task-tracker-audit/` | исторические аудиты |
| `docs/CROSS_PLATFORM_PLAN.md` | будущие клиенты |
| `deploy/DEPLOY.md` | production |
| `.env.example` | env + COMPOSE_PROJECT_NAME |

Зеркало чатов (private): `/Users/gadzhilaev/cursor-context/projects/track/`.

## Команды проверки

```bash
docker compose up db -d
cd backend && ./.venv/bin/pytest
cd frontend && npm test && npm run lint && npm run build
PW_CHANNEL=chrome npm run test:e2e   # при живых :3000 и :8000; после build — рестарт Next
```

## Известные ограничения

- Не менять старые Alembic-миграции ради косметики
- После `npm run build` перезапустить Next (иначе 404 chunks / login на `#`)
- Playwright: `PW_CHANNEL=chrome`
- Цвета статусов/проектов из БД
- Не commit/push/deploy без явного разрешения пользователя
- Python venv не relocatable: после `mv` папки — пересоздать `.venv`

## Статус (обновлено 2026-10-28)

Продукт **Takt**, папка и remote готовы. Официальные SVG подключены. Проверки: pytest 14, vitest 9, lint (1 pre-existing warning), build OK, e2e core-flow 4 passed. Push/deploy — ждут разрешения.
