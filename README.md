# Takt

Платформа управления задачами, проектами и командной работой.

Стек: **FastAPI + PostgreSQL + Next.js 14**, Docker, JWT в httpOnly cookie, WebSocket, Excel-отчёты.

Репозиторий: [github.com/gadzhilaev/takt](https://github.com/gadzhilaev/takt)

Контекст для AI-агентов: [`AGENTS.md`](AGENTS.md) · [`docs/AI_PROJECT_CONTEXT.md`](docs/AI_PROJECT_CONTEXT.md)

## Архитектура

```text
takt/
├── backend/          # FastAPI, SQLAlchemy 2 async, Alembic, pytest
│   └── app/
│       ├── api/      # REST /api/v1, WebSocket /ws
│       ├── core/     # config, security, CSRF
│       ├── models/   # ORM
│       ├── schemas/  # Pydantic v2
│       └── services/ # бизнес-логика
├── frontend/         # Next.js App Router, TanStack Query, dnd-kit
├── deploy/           # Caddy reverse proxy
└── docker-compose.yml
```

- **Прокси (Caddy):** `/` → frontend, `/api/*` и `/ws` → backend.
- **Данные:** PostgreSQL (volume `track_pgdata` при `COMPOSE_PROJECT_NAME=track`), файлы в volume `uploads`.
- **Миграции:** `alembic upgrade head` при старте backend.
- **Первый admin:** из `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME`, если админов ещё нет.

Публичной регистрации нет (`POST /api/v1/auth/register` → 404).

Технические имена БД/Docker (`POSTGRES_USER=track` и т.п.) сохранены для совместимости с существующими volumes — это не название продукта.

## Быстрый старт (Docker)

```bash
cp .env.example .env
# Задайте SECRET_KEY, POSTGRES_PASSWORD, ADMIN_PASSWORD
# Для существующих volumes оставьте COMPOSE_PROJECT_NAME=track

docker compose up --build -d
```

Откройте http://localhost — вход с учётными данными администратора из `.env`.

CLI администратора в контейнере:

```bash
docker compose exec backend python -m app.cli create-admin --email admin@example.com --password 'NewPass123!'
```

## Локальная разработка

1. **PostgreSQL** (Docker Desktop):

```bash
docker compose up db -d
```

2. **Backend** (Python 3.12+):

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

`DATABASE_URL` — из `.env` в корне или `backend/.env`. Пароль должен совпадать с `POSTGRES_PASSWORD`.

3. **Frontend:**

```bash
npm run dev
# или: cd frontend && npm run dev
```

Опционально `frontend/.env.local`: `BACKEND_INTERNAL_URL=http://localhost:8000`

**Тесты:**

```bash
cd backend && pytest && ruff check app tests
cd frontend && npm test && npm run lint && npm run build
# E2E (нужны запущенные frontend+backend):
cd frontend && PW_CHANNEL=chrome npm run test:e2e
```

## HTTPS и домен

Полная инструкция: **[deploy/DEPLOY.md](deploy/DEPLOY.md)**.

## Резервное копирование БД

```bash
docker compose exec db pg_dump -U track track > backup_$(date +%F).sql
cat backup.sql | docker compose exec -T db psql -U track track
```

## Переменные окружения

См. [.env.example](.env.example).
