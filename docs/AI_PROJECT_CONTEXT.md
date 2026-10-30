# AI Project Context — Takt

Точка входа для новых задач. Обновлять краткий статус после крупных этапов.

**Обязательно:** `AGENTS.md`, этот файл, [`docs/README.md`](README.md) и релевантный код.

## Что такое Takt

Простой менеджер проектов и задач вокруг **Kanban-доски** (Next.js + FastAPI + PostgreSQL + Flutter).

После входа — доска последнего доступного проекта (или создание первого).  
Демо-проекты (`is_demo=true`) видны только участникам.

Репозиторий: https://github.com/gadzhilaev/takt · Prod: https://taktapp.ru

## Продуктовая концепция

- Регистрация OTP / вход; приглашения in-app; OAuth VK+Яндекс (+ Apple mobile)
- 4 столбца у новых проектов; новая задача → **первая позиция**
- Срочность через `priority`; удаление задачи — только автор
- Уведомления in-app + Web Push + FCM
- Изолированное демо: `demo@example.com` → «Колледж ДГУ»
- Platform admin `/admin` ≠ project admin ≠ `/app/admin`

## Backend заметки

- Миграции **001–012**, head **012** (`platform_role`, OAuth, moderation)
- Auth: cookies (web) + Bearer (mobile); CSRF skip при Bearer
- Task ACL: доступ только через membership проекта задачи (list без `project_id` scoped)
- Cookie helpers: `app/api/auth_cookies.py` (auth + oauth)
- Env: `DEMO_USER_*`, `VAPID_*`, `FCM_*`, `OAUTH_*`, SMTP — см. `.env.example`
- Login lockout — in-memory (не multi-worker safe)

## Frontend / Mobile

- Routes: `/` landing · `/app/*` workspace · `/admin` platform  
- Токены UI: `globals.css`; бренд `frontend/public/brand/`  
- Flutter: feature-first `data`/`presentation`, Cubit для auth/board; OAuthRepository в DI  

## Команды

```bash
docker compose up db -d
cd backend && ./.venv/bin/alembic upgrade head && ./.venv/bin/pytest -q
cd frontend && npm test && npm run lint && npm run build
cd mobile && flutter analyze && flutter test
# Android emulator: --dart-define=API_BASE=http://10.0.2.2:8000
```

## Статус (обновлено 2026-10-30)

**README polish:** корневой README пересобран как продуктовая страница; скриншоты в `docs/screenshots/readme/` пересняты (web 1440×900, Flutter один симулятор); старые `01–13` — в `docs/screenshots/archive/readme-2026-10-30/`.

**Docs/architecture pass (ранее):** `docs/**`, CI, EditorConfig; аудиты в `docs/archive/`.

**Security:** IDOR `/tasks` закрыт project membership.

**OAuth:** VK/Яндекс web+mobile; Apple mobile-only; admin toggles.

**Не делать без запроса:** commit/push/deploy; возврат report-dashboard UI; массовый Clean Architecture rewrite.
