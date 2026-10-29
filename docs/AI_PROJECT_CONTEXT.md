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

## Статус (обновлено 2026-10-29)

**Docs/architecture pass:** профессиональный README, `docs/**` (architecture/api/security/features/deployment/testing/decisions), CI workflow, EditorConfig; архив устаревших аудитов в `docs/archive/`.

**Security fix:** IDOR на `/tasks` — обязательный project membership для get/update/list scoped.

**OAuth:** VK/Яндекс на login+register (web+mobile); Apple mobile-only; admin toggles `oauth_login_methods`.

**Не делать без запроса:** commit/push/deploy; возврат report-dashboard UI; массовый Clean Architecture rewrite.
