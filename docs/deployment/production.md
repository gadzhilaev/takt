# Production

**Хост:** taktapp.ru (см. private correspondence для SSH — не в git).  
**Путь:** `/opt/takt`.  
**Процесс:** `git pull` + `bash deploy/scripts/server-deploy.sh`.

## Переменные

Скопировать с `.env.example`, обязательно:

- сильные `SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_PASSWORD`  
- `COOKIE_SECURE=true`, корректный `DOMAIN`  
- `NEXT_PUBLIC_WS_URL=wss://…/ws`  
- OAuth / SMTP / VAPID / FCM по необходимости  

## Миграции

Автоматически при старте backend container (`alembic upgrade head`).  
Не редактировать применённые revision-файлы; только новые.

## Backup / restore

```bash
docker compose -f deploy/docker-compose.prod.yml exec db \
  pg_dump -U track track > backup_$(date +%F).sql
```

Restore — через `psql` в контейнер (осторожно: перезапишет данные).

## Rollback

1. `git checkout <previous_sha>` на сервере  
2. `server-deploy.sh --no-pull` или полный redeploy предыдущего образа  
3. DB rollback только при наличии down-migration (Alembic) — по умолчанию предпочитать forward-fix  

Полный HTTPS/DNS runbook: [`../../deploy/DEPLOY.md`](../../deploy/DEPLOY.md).
