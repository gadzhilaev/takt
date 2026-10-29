# AI Project Context — Takt

Точка входа для новых задач. Обновлять краткий статус после крупных этапов.

**Обязательно:** перед работой учитывать `AGENTS.md`, этот файл и релевантный код.

## Что такое Takt

Простой менеджер проектов и задач вокруг **Kanban-доски** (Next.js + FastAPI + PostgreSQL + Flutter).

После входа — доска последнего доступного проекта (или форма «Создайте первый проект»).  
Демо-проекты (`is_demo=true`) видны только участникам; системный admin не получает к ним автоматический доступ.

Репозиторий: https://github.com/gadzhilaev/takt

## Продуктовая концепция

- Регистрация / вход; приглашения по email и поиск зарегистрированных
- 4 столбца у новых проектов; без «Бэклог» в шаблоне
- Новая задача → **первая позиция** столбца
- Срочность через `priority`; удаление задачи — только автор
- Уведомления in-app + Web Push + FCM (mobile, опционально)
- Изолированное демо: `demo@example.com` → проект **«Колледж ДГУ»**
- Mobile: `mobile/` (Flutter), home screen widgets

## Backend заметки

- Миграции: `003`–`007`; `008`/`009` remap standard status colors → Kanban presets (v2 accents)
- Auth: cookies (web) + Bearer (mobile); CSRF пропускается при `Authorization: Bearer`
- Env: `DEMO_USER_*`, `VAPID_*`, `FCM_ENABLED`, `FIREBASE_CREDENTIALS_FILE`
- `scripts/seed_college_demo.py` — идемпотентный сид колледжа

## Команды

```bash
docker compose up db -d
cd backend && ./.venv/bin/alembic upgrade head
./.venv/bin/pytest
cd frontend && npm test && npm run lint && npm run build
cd mobile && flutter analyze && flutter test
# Android emulator API: --dart-define=API_BASE=http://10.0.2.2:8000
```

## Статус (обновлено 2026-10-29)

**Web routes:** `/` landing; `/login` `/register`; workspace `/app/*`; **платформенная админка** `/admin` (не project_admin). Миграция `012`: `platform_role`, OAuth identities, moderation, activity events.

**OAuth:** Apple / VK ID / Яндекс ID — каркас API + UI; credentials в `.env` (см. `docs/OAUTH_SETUP.md`). По умолчанию выключены; для оператора РФ Apple блокируется политикой до юр. решения (149-ФЗ). Реальный вход провайдеров **не** помечать готовым без smoke-теста.

**Auth UX:** кнопка регистрации — «Зарегистрироваться»; web/mobile парсят `detail.error.message` и SlowAPI rate-limit (не голый «Ошибка запроса»).

**Prod:** https://taktapp.ru. Commit/push/deploy только по разрешению.
