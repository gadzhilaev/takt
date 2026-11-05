# Развёртывание Takt

Production: **https://taktapp.ru** · путь на сервере: **`/opt/takt`**.  
Стек: PostgreSQL 16 · FastAPI · Next.js 14 · edge nginx (или Caddy в standalone).  
Репозиторий: https://github.com/gadzhilaev/takt

Локальная разработка: [`../docs/development.md`](../docs/development.md). OAuth: [`../docs/oauth.md`](../docs/oauth.md).

---

## 1. Контуры

### Shared VPS (taktapp.ru)

`deploy/docker-compose.prod.yml`:

- сеть `gadzhilaev_internal` (external)
- secrets volume (`TAKT_SECRETS_DIR`)
- edge nginx на хосте: `deploy/docker-compose.takt-edge.yml`, конфиги в `deploy/nginx/`

Выкат:

```bash
cd /opt/takt
./deploy/scripts/server-deploy.sh
# уже на нужном commit:
# ./deploy/scripts/server-deploy.sh --no-pull
```

Скрипт: `git pull --ff-only origin main` → `docker compose -f deploy/docker-compose.prod.yml build` → `up -d`.  
Миграции Alembic (**001–016**) применяются при старте backend (`alembic upgrade head`).  
SSH deploy key: `~/.ssh/takt_deploy` (read-only). Секреты (`.env`, `secrets/`) в git не входят.

### Standalone (свой VPS + Compose Caddy)

Корневой `docker-compose.yml`: `db`, `backend`, `frontend`, `proxy` (Caddy + Let's Encrypt).  
Volumes: `pgdata`, `uploads`, `caddy_*`. `COMPOSE_PROJECT_NAME=track` сохраняет `track_pgdata`.

```bash
cd /opt/takt
cp .env.example .env && chmod 600 .env
# SECRET_KEY, POSTGRES_PASSWORD, ADMIN_*, DOMAIN, ACME_EMAIL, COOKIE_SECURE=true
docker compose up --build -d
```

Технические имена БД (`POSTGRES_USER=track` и т.п.) — legacy ids, не бренд продукта.

---

## 2. Требования к серверу

| Параметр | Минимум | Рекомендуется |
|----------|---------|---------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 2 GB | 4 GB |
| Диск | 20 GB SSD | 40+ GB |
| ОС | Ubuntu 22.04/24.04 | Ubuntu LTS |
| Порты | 80, 443 (+ 22 для SSH) | PostgreSQL **не** снаружи |

---

## 3. DNS и `.env`

A-запись домена → IP VPS. Переменные: [`.env.example`](../.env.example).

Обязательно на production:

| Переменная | Значение |
|------------|----------|
| `SECRET_KEY` | `openssl rand -hex 32` |
| `POSTGRES_PASSWORD` | сильный пароль |
| `ENV` | `production` |
| `DEBUG` | `false` |
| `COOKIE_SECURE` | `true` |
| `CORS_ORIGINS` | `https://taktapp.ru` (ваш HTTPS origin) |
| `SEED_DEMO_DATA` | `false` |
| `NEXT_PUBLIC_API_URL` | пусто (same-origin `/api`) |
| `NEXT_PUBLIC_WS_URL` | `wss://taktapp.ru/ws` |
| `ADMIN_*` | первый bootstrap-admin, если админов ещё нет |

Опционально: SMTP, VAPID, FCM, `OAUTH_*` — см. oauth.md и `.env.example`.

Генерация секретов:

```bash
openssl rand -hex 32    # SECRET_KEY
openssl rand -base64 24 # POSTGRES_PASSWORD
```

---

## 4. Первый запуск и проверка

```bash
cd /opt/takt
docker compose -f deploy/docker-compose.prod.yml up --build -d   # shared
# или: docker compose up --build -d                               # standalone
docker compose ps
docker compose logs -f --tail=100
```

1. Откройте HTTPS URL — страница входа.
2. Войдите `ADMIN_EMAIL` / `ADMIN_PASSWORD`, смените пароль.
3. Регистрация по email (OTP) и OAuth — если credentials настроены.
4. Создайте проект → задачу (≥1 исполнитель) → проверьте доску и WebSocket.
5. Health: `docker compose exec backend curl -sS http://localhost:8000/health`

Создание admin вручную:

```bash
docker compose exec backend python -m app.cli create-admin \
  --email you@example.com --password '…' --name 'Админ'
```

Platform role:

```bash
docker compose exec backend python -m app.cli grant-super-admin --email you@example.com
```

---

## 5. Обновление

```bash
cd /opt/takt
./deploy/scripts/server-deploy.sh          # shared
# или: git pull && docker compose build && docker compose up -d
```

Rollback: `git checkout <sha>` на сервере + redeploy. DB down-migration — только при наличии; предпочтителен forward-fix.

---

## 6. Backup и restore

```bash
# dump
docker compose -f deploy/docker-compose.prod.yml exec -T db \
  pg_dump -U track -d track --format=custom > backup_$(date +%F).dump

# uploads volume (имя может быть track_uploads — проверьте docker volume ls)
docker run --rm -v track_uploads:/data -v "$PWD/backups":/backup alpine \
  tar czf /backup/uploads_$(date +%F).tar.gz -C /data .
```

Restore перезапишет данные — остановите backend/frontend перед `pg_restore` / `dropdb`.

---

## 7. Логи и типичные проблемы

```bash
docker compose logs backend -f --tail=200
docker compose logs frontend -f --tail=200
```

| Симптом | Что проверить |
|---------|----------------|
| 502 | логи backend/frontend, healthcheck |
| Cookie не держится | `COOKIE_SECURE=true`, `CORS_ORIGINS` = HTTPS origin |
| WebSocket | `NEXT_PUBLIC_WS_URL=wss://…/ws`, пересборка frontend |
| HTTPS / ACME | DNS, порт 80, firewall |
| Пустая БД после «миграции» | не переименовывали volume `track_pgdata` |

---

## 8. Чеклист production

- [ ] DNS на IP сервера
- [ ] Уникальные `SECRET_KEY`, `POSTGRES_PASSWORD`
- [ ] `ENV=production`, `DEBUG=false`, `COOKIE_SECURE=true`
- [ ] `SEED_DEMO_DATA=false`
- [ ] `NEXT_PUBLIC_WS_URL` с `wss://`
- [ ] Firewall: 22 / 80 / 443; БД не снаружи
- [ ] Cron / внешний backup `pg_dump`
- [ ] `.env` права `600`, не в git
- [ ] OAuth / FCM / SMTP — только при реальных credentials
