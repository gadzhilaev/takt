# Тестирование

## Backend

Нужен Postgres:

```bash
docker compose up db -d
# БД track_test создаётся вручную при первом прогоне, если отсутствует:
docker compose exec db psql -U track -c "CREATE DATABASE track_test;"
cd backend && ./.venv/bin/pytest -q
# полный стиль: ./.venv/bin/ruff check app tests
# CI: только критические F821/F822/E9
./.venv/bin/ruff check app tests --select F821,F822,E9
```

`tests/conftest.py` **жёстко** задаёт `DATABASE_URL` на `track_test` (не использовать рабочую `track`).  
Схема: `drop_all` / `create_all` из ORM (не Alembic) — после смены моделей сверяйте с миграциями вручную.

## Frontend

```bash
cd frontend
npm test                 # Vitest
npm run lint
npm run build
PW_CHANNEL=chrome npm run test:e2e   # Playwright; нужен live стек
```

E2E логинится как demo-пользователь и пишет только в demo / `[E2E] Playwright` проекты.

## Flutter

```bash
cd mobile
flutter analyze
flutter test
```

## CI

[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml): backend (Postgres service + pytest + ruff), frontend (lint/test/build), mobile (analyze/test).
