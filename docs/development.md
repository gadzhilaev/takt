# Разработка и тестирование

## Принципы

1. Читать [`AGENTS.md`](../AGENTS.md).
2. Не ломать API-контракты и уже применённые миграции.
3. Не возвращать сложные UI (отчёты/фильтры) без запроса.
4. Не коммитить секреты.
5. Commit / push / deploy — только с разрешения владельца.
6. После существенных этапов — краткий статус в `AGENTS.md` (секция «Статус»).

## Локальный контур

Предпосылки: Docker (Postgres), Python 3.12+, Node 20+, Flutter (для mobile).  
`.env.example` → `.env` (`SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_*`).

```bash
docker compose up db -d

cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000

cd frontend && npm ci && npm run dev
# опционально: BACKEND_INTERNAL_URL=http://localhost:8000 в frontend/.env.local

cd mobile && flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
# Android emulator: API_BASE=http://10.0.2.2:8000
```

Полный стек: `docker compose up --build -d` → http://localhost.

Демо: `SEED_DEMO_DATA=true`; скрипты `setup_demo_workspace.py`, `seed_college_demo.py`; учётка `DEMO_USER_*` (не в git).

## Стиль кода

- Python: Ruff; async SQLAlchemy 2; Pydantic v2
- TypeScript: next lint
- Dart: `flutter analyze`
- EditorConfig: [`.editorconfig`](../.editorconfig)
- Коммиты на русском, без Conventional Commits; без AI co-authored trailers

## Миграции

```bash
cd backend
alembic revision -m "short_description"
alembic upgrade head
```

Не переписывать выкатанные revision на production.

## Тесты

### Backend

```bash
docker compose up db -d
docker compose exec db psql -U track -c "CREATE DATABASE track_test;"  # при первом прогоне
cd backend && ./.venv/bin/pytest -q
./.venv/bin/ruff check app tests
# CI: --select F821,F822,E9
```

`conftest.py` жёстко использует `track_test`. Схема из ORM `create_all`, не Alembic.

### Frontend

```bash
cd frontend
npm test && npm run lint && npm run build
PW_CHANNEL=chrome npm run test:e2e   # нужен live стек; пишет в demo / [E2E]
```

### Flutter

```bash
cd mobile && flutter analyze && flutter test
```

### CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml): backend + frontend + mobile.
