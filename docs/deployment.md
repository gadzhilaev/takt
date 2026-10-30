# Развёртывание

Переменные: [`.env.example`](../.env.example).  
Подробный HTTPS/DNS runbook: [`../deploy/DEPLOY.md`](../deploy/DEPLOY.md).  
OAuth credentials: [oauth.md](oauth.md).

## Docker (локально / полный стек)

Корневой `docker-compose.yml`: `db`, `backend`, `frontend`, `proxy` (Caddy).  
Volumes: `pgdata`, `uploads`, `caddy_*`.  
`COMPOSE_PROJECT_NAME=track` сохраняет `track_pgdata`.

```bash
cp .env.example .env
docker compose up --build -d
# http://localhost
```

Backend при старте: Alembic + bootstrap admin.

## Production compose

`deploy/docker-compose.prod.yml`:

- Сеть `gadzhilaev_internal` (external)
- Secrets volume (`TAKT_SECRETS_DIR`)
- Edge nginx на хосте (`docker-compose.takt-edge.yml`)

Выкат: `deploy/scripts/server-deploy.sh` на сервере (`/opt/takt`).

## Production

**Сайт:** https://taktapp.ru · **Путь:** `/opt/takt`.

Обязательно в `.env`: сильные `SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_PASSWORD`; `COOKIE_SECURE=true`; `NEXT_PUBLIC_WS_URL=wss://…/ws`; OAuth / SMTP / VAPID / FCM по необходимости.

Миграции: автоматически при старте backend (`alembic upgrade head`).

### Backup

```bash
docker compose -f deploy/docker-compose.prod.yml exec db \
  pg_dump -U track track > backup_$(date +%F).sql
```

Restore — через `psql` в контейнер (перезапишет данные).

### Rollback

1. `git checkout <previous_sha>` на сервере  
2. `server-deploy.sh` (или redeploy предыдущего образа)  
3. DB down-migration — только при наличии; предпочтителен forward-fix  
