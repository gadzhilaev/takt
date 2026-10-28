# Трекер задач (командный)

Production-ready стек: **FastAPI + PostgreSQL + Next.js 14**, Docker, JWT в httpOnly cookie, WebSocket, Excel-отчёты.

## Архитектура

```text
track/
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
- **Данные:** PostgreSQL (volume `pgdata`), файлы в volume `uploads`.
- **Миграции:** `alembic upgrade head` при старте backend.
- **Первый admin:** из `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME`, если админов ещё нет.

Публичной регистрации нет (`POST /api/v1/auth/register` → 404).

## Быстрый старт (Docker)

```bash
cp .env.example .env
# Задайте SECRET_KEY, POSTGRES_PASSWORD, ADMIN_PASSWORD

docker compose up --build -d
```

Откройте http://localhost — вход с учётными данными администратора из `.env`.

CLI администратора в контейнере:

```bash
docker compose exec backend python -m app.cli create-admin --email admin@example.com --password 'NewPass123!'
```

## Локальная разработка (Windows)

1. **Поднять только PostgreSQL** (нужен запущенный Docker Desktop):

```powershell
cd track
docker compose up db -d
```

2. **Зависимости backend** (рекомендуется Python **3.12**; на 3.13 тоже работает):

```powershell
cd backend
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

`DATABASE_URL` берётся из `.env` в **корне** репозитория или из `backend/.env`. Пароль должен совпадать с `POSTGRES_PASSWORD` в `.env` (по умолчанию `track_dev_pass`).

3. **Frontend** — из корня или из `frontend/`:

```powershell
cd track
npm run dev
# то же самое: cd frontend && npm run dev
```

В `frontend/.env.local` (опционально): `BACKEND_INTERNAL_URL=http://localhost:8000`

**Ошибка `WinError 64` / `connection was closed` при `alembic`:** PostgreSQL не запущен или неверный `DATABASE_URL`. Проверьте: `docker compose ps`, затем снова `alembic upgrade head`.

**`npm run dev` в корне без package.json:** используйте `npm run dev` из корня после `git pull` (есть корневой `package.json`) или `cd frontend`.

**Тесты:**

```bash
cd backend
# БД track_test должна существовать
pytest
ruff check app tests
```

## HTTPS и домен

Полная пошаговая инструкция (сервер, DNS, `.env`, Caddy, бэкапы): **[deploy/DEPLOY.md](deploy/DEPLOY.md)**.

Кратко:

1. Укажите `DOMAIN=tasks.example.com` и `ACME_EMAIL` в `.env`.
2. Пробросьте порты 80/443 на сервер.
3. Установите `COOKIE_SECURE=true`, `CORS_ORIGINS=https://tasks.example.com`, `NEXT_PUBLIC_WS_URL=wss://tasks.example.com/ws`.
4. `docker compose up -d` — Caddy получит сертификат Let's Encrypt.

## Резервное копирование БД

```bash
docker compose exec db pg_dump -U track track > backup_$(date +%F).sql
# Восстановление:
cat backup.sql | docker compose exec -T db psql -U track track
```

## Чеклист проверки

1. Вход под admin из `.env`
2. Админка → создать пользователя, скопировать логин/пароль
3. Вход под пользователем → принудительная смена пароля
4. Доска → создать задачу (C или «+»), перетащить в «Готово»
5. Назначить исполнителя в карточке (PATCH через drawer — статус/приоритет)
6. Отключить пользователя в админке
7. Страница «Отчёт» и скачивание Excel
8. Открыть с телефона — горизонтальный скролл колонок, смена статуса в карточке

## Переменные окружения

См. [.env.example](.env.example).
