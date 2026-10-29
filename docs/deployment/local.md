# Локальная разработка

## Предпосылки

- Docker Desktop (Postgres)  
- Python 3.12+, Node 20+, Flutter stable (для mobile)  
- Скопировать `.env.example` → `.env`, выставить `SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_*`

## Минимальный контур

```bash
docker compose up db -d
cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# DATABASE_URL → localhost:5433 и пароль как в .env
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

```bash
cd frontend && npm ci && npm run dev
```

Опционально: `BACKEND_INTERNAL_URL=http://localhost:8000` в `frontend/.env.local`.

## Mobile

```bash
cd mobile
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
```

## Полный Docker-стек

```bash
docker compose up --build -d
# http://localhost через Caddy
```

## Демо-данные

- `SEED_DEMO_DATA=true` — общий seed при старте  
- `backend/scripts/setup_demo_workspace.py`, `seed_college_demo.py` — изолированное демо «Колледж ДГУ»  
- Учётка: `DEMO_USER_EMAIL` / `DEMO_USER_PASSWORD` (не коммитить пароль)
