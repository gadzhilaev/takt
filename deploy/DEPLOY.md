# Развёртывание Takt на сервере

Пошаговая инструкция: от чистого VPS до работающего сайта с HTTPS.  
Стек: **PostgreSQL 16** + **FastAPI** + **Next.js 14** + **Caddy** (reverse proxy и Let's Encrypt).  
Репозиторий: https://github.com/gadzhilaev/takt

---

## Содержание

1. [Что получится в итоге](#1-что-получится-в-итоге)
2. [Требования к серверу](#2-требования-к-серверу)
3. [Подготовка сервера (Ubuntu 22.04/24.04)](#3-подготовка-сервера-ubuntu-22042404)
4. [Установка Docker](#4-установка-docker)
5. [DNS и домен](#5-dns-и-домен)
6. [Копирование проекта на сервер](#6-копирование-проекта-на-сервер)
7. [Файл `.env` — каждая переменная](#7-файл-env--каждая-переменная)
8. [Прокси `deploy/Caddyfile`](#8-прокси-deploycaddyfile)
9. [Первый запуск](#9-первый-запуск)
10. [Проверка после деплоя](#10-проверка-после-деплоя)
11. [Администратор и безопасность](#11-администратор-и-безопасность)
12. [Обновление версии](#12-обновление-версии)
13. [Резервное копирование и восстановление](#13-резервное-копирование-и-восстановление)
14. [Логи и диагностика](#14-логи-и-диагностика)
15. [Типичные проблемы](#15-типичные-проблемы)
16. [Чеклист production](#16-чеклист-production)

---

## 1. Что получится в итоге

```text
Интернет
   │
   ▼
[Caddy :80 / :443]  ← HTTPS, сертификат Let's Encrypt
   │
   ├── /api/*  ──► backend:8000  (FastAPI, PostgreSQL, файлы)
   ├── /ws     ──► backend:8000  (WebSocket)
   └── /*      ──► frontend:3000 (Next.js)

[PostgreSQL] — только внутри Docker-сети (порт 5432 наружу не проброшен)
[volumes]    — pgdata (БД), uploads (аватары/файлы), caddy_data (сертификаты)
```

Пользователи заходят на `https://tasks.example.com`. API и фронт — **один домен** (cookie и CSRF работают без кросс-доменных настроек).

---

## 2. Требования к серверу

| Параметр | Минимум | Рекомендуется |
|----------|---------|---------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 2 GB | 4 GB |
| Диск | 20 GB SSD | 40+ GB SSD |
| ОС | Linux (Ubuntu 22.04/24.04, Debian 12) | Ubuntu LTS |
| Сеть | Публичный IPv4 | + IPv6 по желанию |

Нужны открытые порты **80** и **443** (HTTP для проверки ACME, HTTPS для сайта).  
PostgreSQL **не** должен быть доступен из интернета — в `docker-compose.yml` порт БД наружу не публикуется.

---

## 3. Подготовка сервера (Ubuntu 22.04/24.04)

Подключитесь по SSH:

```bash
ssh root@ВАШ_IP
# или
ssh deploy@ВАШ_IP
```

### 3.1. Обновление системы

```bash
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Europe/Moscow   # или ваш часовой пояс
```

### 3.2. Пользователь для деплоя (не обязательно, но лучше)

```bash
sudo adduser deploy
sudo usermod -aG sudo deploy
sudo usermod -aG docker deploy   # после установки Docker
```

Дальнейшие команды — от `deploy` или `root`.

### 3.3. Firewall (ufw)

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

Не открывайте `5432` наружу, если не знаете зачем это нужно.

### 3.4. Swap (если RAM 2 GB)

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 4. Установка Docker

Официальный способ (Docker Engine + Compose plugin):

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
docker compose version
```

Проверка:

```bash
docker run hello-world
```

---

## 5. DNS и домен

1. Купите/используйте домен, например `example.com`.
2. Создайте **A-запись** (и при желании AAAA для IPv6):

| Тип | Имя | Значение | TTL |
|-----|-----|----------|-----|
| A | `tasks` | IP вашего VPS | 300 |

Итог: `tasks.example.com` → IP сервера.

Подождите 5–30 минут, проверьте:

```bash
dig +short tasks.example.com
# или
nslookup tasks.example.com
```

---

## 6. Копирование проекта на сервер

### Вариант A: Git

```bash
sudo mkdir -p /opt/track
sudo chown $USER:$USER /opt/track
cd /opt/track
git clone https://ВАШ_РЕПОЗИТОРИЙ/track.git .
```

### Вариант B: архив с локальной машины

```bash
# на локальном ПК (без node_modules и .next)
scp -r track deploy@ВАШ_IP:/opt/
```

На сервере:

```bash
cd /opt/track
```

---

## 7. Файл `.env` — каждая переменная

Создайте конфиг из шаблона:

```bash
cd /opt/track
cp .env.example .env
chmod 600 .env
nano .env
```

### 7.1. Общие и домен

| Переменная | Пример | Назначение |
|------------|--------|------------|
| `DOMAIN` | `tasks.example.com` | Домен для Caddy и HTTPS. **Без** `https://`. |
| `HTTP_PORT` | `80` | Порт HTTP на хосте (проброс в Caddy). |
| `HTTPS_PORT` | `443` | Порт HTTPS на хосте. |
| `ACME_EMAIL` | `admin@example.com` | Email для Let's Encrypt (уведомления об истечении). |

### 7.2. PostgreSQL (контейнер `db`)

| Переменная | Пример | Назначение |
|------------|--------|------------|
| `POSTGRES_USER` | `track` | Пользователь БД внутри Docker. |
| `POSTGRES_PASSWORD` | длинный случайный пароль | Пароль БД. **Не используйте** `track` или `123456`. |
| `POSTGRES_DB` | `track` | Имя базы данных. |

В `docker-compose.yml` backend получает:

`DATABASE_URL=postgresql+asyncpg://track:ПАРОЛЬ@db:5432/track`

Хост **`db`** — имя сервиса в Docker, не `localhost`. Переопределять `DATABASE_URL` в `.env` для production **не нужно**, если не выносите БД на отдельный сервер.

Для **локальной разработки** на Windows (Postgres только через `docker compose up db`) в `.env` может быть:

`DATABASE_URL=postgresql+asyncpg://track:ПАРОЛЬ@localhost:5432/track`

### 7.3. Backend (безопасность и админ)

| Переменная | Production | Назначение |
|------------|------------|------------|
| `SECRET_KEY` | `openssl rand -hex 32` | Подпись JWT и CSRF. Минимум 32 символа, уникально на сервер. |
| `ENV` | `production` | Режим приложения. |
| `DEBUG` | `false` | Не показывать трассировки клиенту. |
| `COOKIE_SECURE` | `true` | Cookie только по HTTPS. **Обязательно** с Caddy и HTTPS. |
| `COOKIE_DOMAIN` | пусто или `.example.com` | Обычно **пусто** — cookie на текущий хост. |
| `CORS_ORIGINS` | `https://tasks.example.com` | Разрешённый origin (без слэша в конце). |
| `ADMIN_EMAIL` | `admin@company.com` | Первый админ, если в БД ещё нет админов. |
| `ADMIN_PASSWORD` | надёжный пароль | Только для **первого** создания; смените после входа. |
| `ADMIN_NAME` | `Администратор` | Отображаемое имя. |
| `SEED_DEMO_DATA` | `false` | На production **всегда false**. |
| `LOGIN_LOCKOUT_ATTEMPTS` | `5` | Попытки входа до блокировки. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Длительность блокировки. |

`UPLOAD_DIR` в compose задаётся как `/data/uploads` внутри контейнера — менять в `.env` для Docker обычно не нужно.

### 7.4. Frontend (публичные URL)

При работе через **один домен** (Caddy отдаёт и `/`, и `/api`):

| Переменная | Production | Назначение |
|------------|------------|------------|
| `NEXT_PUBLIC_API_URL` | **пусто** | Запросы идут на тот же origin: `/api/v1/...`. |
| `NEXT_PUBLIC_WS_URL` | `wss://tasks.example.com/ws` | WebSocket для доски в реальном времени. |

Если `NEXT_PUBLIC_API_URL` указать с другим доменом — придётся настраивать CORS и cookie отдельно; для этого проекта **не рекомендуется**.

### 7.5. Пример готового `.env` для production

```env
DOMAIN=tasks.example.com
HTTP_PORT=80
HTTPS_PORT=443
ACME_EMAIL=admin@example.com

POSTGRES_USER=track
POSTGRES_PASSWORD=ЗАМЕНИТЕ_СГЕНЕРИРОВАННЫМ_ПАРОЛЕМ
POSTGRES_DB=track

SECRET_KEY=ЗАМЕНИТЕ_openssl_rand_hex_32
ENV=production
DEBUG=false
COOKIE_SECURE=true
COOKIE_DOMAIN=
CORS_ORIGINS=https://tasks.example.com

ADMIN_EMAIL=admin@company.com
ADMIN_PASSWORD=ВременныйСильныйПароль123!
ADMIN_NAME=Администратор
SEED_DEMO_DATA=false

NEXT_PUBLIC_API_URL=
NEXT_PUBLIC_WS_URL=wss://tasks.example.com/ws
```

Генерация секретов на сервере:

```bash
openssl rand -hex 32    # SECRET_KEY
openssl rand -base64 24 # POSTGRES_PASSWORD
```

---

## 8. Прокси `deploy/Caddyfile`

Файл уже в репозитории. Caddy читает переменные из окружения контейнера `proxy` (из `.env` через compose).

```caddyfile
{
	email {$ACME_EMAIL}
}

{$DOMAIN:localhost} {
	encode gzip

	handle /api/* {
		reverse_proxy backend:8000
	}

	handle /ws {
		reverse_proxy backend:8000
	}

	handle {
		reverse_proxy frontend:3000
	}
}
```

| Блок | Назначение |
|------|------------|
| `email` | Контакт ACME (Let's Encrypt). |
| `{$DOMAIN}` | Сайт и автоматический HTTPS для этого имени. |
| `/api/*` | REST API FastAPI (`/api/v1/...`). |
| `/ws` | WebSocket (обновления канбана). |
| остальное | Next.js (страницы, статика). |

**Важно:** на production `DOMAIN` должен совпадать с DNS и быть доступен с интернета на порту 80 до выпуска сертификата.

Пересборка frontend при смене `NEXT_PUBLIC_WS_URL`:

```bash
docker compose build frontend --no-cache
docker compose up -d frontend
```

---

## 9. Первый запуск

```bash
cd /opt/track
docker compose up --build -d
```

Что происходит:

1. **db** — PostgreSQL 16, volume `pgdata`.
2. **backend** — сборка образа, `alembic upgrade head`, создание первого admin (если нет), healthcheck `/health`.
3. **frontend** — сборка Next.js (standalone).
4. **proxy** — Caddy, порты 80/443.

Проверка статуса:

```bash
docker compose ps
docker compose logs -f --tail=100
```

Все сервисы должны быть `healthy` / `running`. Первый запуск frontend/backend может занять 5–15 минут.

---

## 10. Проверка после деплоя

1. Откройте `https://tasks.example.com` — страница входа на русском.
2. Войдите: `ADMIN_EMAIL` / `ADMIN_PASSWORD` из `.env`.
3. Смените пароль админа: **Профиль** или создайте нового admin и отключите старый.
4. **Админка** → добавьте пользователя, проверьте вход под ним.
5. **Доска** → создайте задачу, смените статус.
6. **Отчёт** → скачайте Excel.
7. WebSocket: откройте доску в двух браузерах — изменения должны подтягиваться без F5.

Проверка API с сервера:

```bash
curl -sS https://tasks.example.com/api/v1/settings/statuses
# без cookie — 401, это нормально

curl -sS http://127.0.0.1/health
# через Caddy на localhost, если DOMAIN=localhost — иначе смотрите backend:
docker compose exec backend curl -sS http://localhost:8000/health
```

---

## 11. Администратор и безопасность

### Создание / сброс admin

```bash
docker compose exec backend python -m app.cli create-admin \
  --email admin@company.com \
  --password 'НовыйНадёжныйПароль!' \
  --name 'Главный админ'
```

### Рекомендации

- Публичной регистрации нет — пользователей создаёт только admin.
- Не коммитьте `.env` в git (`chmod 600 .env`).
- После первого входа смените `ADMIN_PASSWORD` в `.env` (на уже созданного admin это не влияет, но секрет не должен лежать в файле).
- Регулярно обновляйте образы: `docker compose pull` (для `postgres`, `caddy`) и пересборка своих образов.

---

## 12. Обновление версии

```bash
cd /opt/track
git pull   # или залейте новый код

docker compose build --no-cache
docker compose up -d

docker compose ps
docker image prune -f   # по желанию, освободить место
```

Миграции БД применяются при **старте backend** автоматически.

---

## 13. Резервное копирование и восстановление

### 13.1. База PostgreSQL

**Бэкап:**

```bash
cd /opt/track
docker compose exec -T db pg_dump -U track -d track --format=custom -f /tmp/track.dump
docker compose cp db:/tmp/track.dump ./backups/track_$(date +%F_%H%M).dump
```

Папку `backups/` храните **вне** сервера (S3, другой VPS, локальный ПК).

**Cron (ежедневно в 3:00):**

```bash
mkdir -p /opt/track/backups
crontab -e
```

```cron
0 3 * * * cd /opt/track && docker compose exec -T db pg_dump -U track -d track --format=custom > /opt/track/backups/track_$(date +\%F).dump 2>> /var/log/track-backup.log
```

**Восстановление** (осторожно: перезапишет данные):

```bash
docker compose stop backend frontend proxy
docker compose exec -T db dropdb -U track --if-exists track
docker compose exec -T db createdb -U track track
docker compose cp ./backups/track_2026-03-25.dump db:/tmp/restore.dump
docker compose exec -T db pg_restore -U track -d track --clean --if-exists /tmp/restore.dump
docker compose up -d
```

### 13.2. Загруженные файлы (аватары)

Volume `uploads`. Бэкап через временный контейнер:

```bash
docker run --rm -v track_uploads:/data -v /opt/track/backups:/backup alpine \
  tar czf /backup/uploads_$(date +%F).tar.gz -C /data .
```

Имя volume может быть `track_uploads` или с префиксом папки — проверьте:

```bash
docker volume ls | grep uploads
```

---

## 14. Логи и диагностика

```bash
docker compose logs backend -f --tail=200
docker compose logs frontend -f --tail=200
docker compose logs proxy -f --tail=200
docker compose logs db -f --tail=100
```

Healthcheck:

```bash
docker compose ps
docker inspect --format='{{json .State.Health}}' track-backend-1 | jq
```

Место на диске:

```bash
df -h
docker system df
```

---

## 15. Типичные проблемы

| Симптом | Причина | Решение |
|---------|---------|---------|
| Caddy не выдаёт HTTPS | DNS не указывает на сервер, порт 80 закрыт | `dig`, `ufw`, провайдер firewall |
| 502 Bad Gateway | backend/frontend не поднялись | `docker compose logs backend frontend` |
| Вход не сохраняется | `COOKIE_SECURE=false` на HTTPS или неверный `CORS_ORIGINS` | `COOKIE_SECURE=true`, origin = ваш URL |
| WebSocket не работает | неверный `NEXT_PUBLIC_WS_URL` | `wss://ВАШ_ДОМЕН/ws`, пересборка frontend |
| «Неверный email или пароль» | admin ещё не создан, другая БД | логи backend, `create-admin` |
| Alembic / БД на Windows | Postgres не запущен или другой пароль на :5432 | `docker compose up db -d`, пароль = `POSTGRES_PASSWORD` |

---

## 16. Чеклист production

- [ ] DNS A-запись на IP сервера
- [ ] `.env`: уникальные `SECRET_KEY`, `POSTGRES_PASSWORD`
- [ ] `ENV=production`, `DEBUG=false`, `COOKIE_SECURE=true`
- [ ] `CORS_ORIGINS` = ваш HTTPS URL
- [ ] `SEED_DEMO_DATA=false`
- [ ] `NEXT_PUBLIC_API_URL` пустой, `NEXT_PUBLIC_WS_URL` с `wss://`
- [ ] Firewall: только 22, 80, 443
- [ ] Первый вход admin и смена пароля
- [ ] Настроен cron бэкапа `pg_dump`
- [ ] `.env` права `600`, не в git

---

## Краткая шпаргалка команд

```bash
cd /opt/track
cp .env.example .env && nano .env
docker compose up --build -d
docker compose ps
docker compose logs -f
docker compose exec backend python -m app.cli create-admin --email you@corp.com --password '***'
docker compose down          # остановить (данные в volumes сохранятся)
docker compose down -v       # ОПАСНО: удалит volumes включая БД
```

Документация по локальной разработке на Windows — в [README.md](../README.md).
