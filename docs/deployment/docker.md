# Docker

## Корневой `docker-compose.yml`

Сервисы: `db`, `backend`, `frontend`, `proxy` (Caddy).  
Volumes: `pgdata`, `uploads`, `caddy_*`.  
`COMPOSE_PROJECT_NAME=track` сохраняет имя volume `track_pgdata`.

Backend при старте: Alembic + bootstrap admin.

## Production compose

`deploy/docker-compose.prod.yml`:

- Сеть `gadzhilaev_internal` (external) для shared VPS  
- Secrets volume (`TAKT_SECRETS_DIR`)  
- Без встроенного Caddy — edge nginx на хосте (`docker-compose.takt-edge.yml`)

Сборка/выкат: `deploy/scripts/server-deploy.sh`.
