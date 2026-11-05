<p align="center">
  <img src="docs/brand/takt-logo-readme.png" alt="Takt" width="220" />
</p>

<h1 align="center">Takt</h1>

<p align="center"><strong>Работа команды. В одном ритме.</strong></p>

<p align="center">
  Простой менеджер проектов и задач вокруг Kanban-доски.<br />
  Web · API · Mobile · PostgreSQL
</p>

<p align="center">
  <a href="https://taktapp.ru">taktapp.ru</a>
  ·
  <a href="docs/architecture.md">Архитектура</a>
  ·
  <a href=".github/workflows/ci.yml">CI</a>
</p>

---

## О продукте

Takt помогает небольшим командам вести проекты на одной доске: регистрация и вход, проекты и участники, столбцы-состояния, задачи с исполнителями и срочностью, уведомления.

Без перегруженных дашбордов и сложных фильтров в основном UI. Демо-окружение изолировано (`projects.is_demo`).

## Возможности

- Регистрация по email (OTP), вход по паролю, сброс пароля кодом из письма
- OAuth: VK ID и Яндекс ID (web + mobile); Sign in with Apple — только в мобильном приложении ([docs/oauth.md](docs/oauth.md))
- Проекты с ролями `admin` / `member` / `viewer` и приглашениями in-app (email или ссылка)
- Kanban: 4 стартовых столбца, drag-and-drop; новая задача всегда в начало столбца
- Задача: название, описание, исполнители (**≥1**), приоритет, вложения, история, комментарии, чеклист
- Удаление аккаунта: в профиле (web/mobile) и страница `/account-delete`
- Уведомления: короткий in-app copy, Web Push (VAPID), FCM на mobile
- Платформенная админка `/admin` (`platform_role`)
- Home screen widgets (iOS / Android) без JWT в виджете

## Интерфейс

Скриншоты только здесь (`docs/screenshots/readme/`). Демо-данные: проект «Запуск продукта», команда из 5 участников — `backend/scripts/seed_readme_demo.py`.

### Web

<p align="center">
  <img src="docs/screenshots/readme/web-landing.png" alt="Takt — лендинг" width="920" />
</p>

<p align="center"><em>Лендинг · вход и регистрация</em></p>

<p align="center">
  <img src="docs/screenshots/readme/web-kanban-light.png" alt="Takt — Kanban на web" width="920" />
</p>

<p align="center"><em>Светлая тема · доска «Запуск продукта»</em></p>

<p align="center">
  <img src="docs/screenshots/readme/web-kanban-dark.png" alt="Takt — Kanban, тёмная тема" width="720" />
</p>

<p align="center"><em>Тёмная тема · те же столбцы и задачи</em></p>

### Mobile

<p align="center">
  <img src="docs/screenshots/readme/mobile-login.png" alt="Вход" width="230" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/readme/mobile-kanban.png" alt="Доска" width="230" />
</p>

<p align="center"><em>Вход (Apple / VK / Яндекс) · доска проекта</em></p>

<p align="center">
  <img src="docs/screenshots/readme/mobile-my-tasks.png" alt="Мои задачи" width="230" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/readme/mobile-profile.png" alt="Профиль" width="230" />
</p>

<p align="center"><em>Мои задачи · профиль</em></p>

## Стек

| Слой | Технологии |
|------|------------|
| Frontend | Next.js 14 (App Router), React 18, TanStack Query, dnd-kit, Tailwind CSS, Playwright, Vitest |
| Mobile | Flutter, Dio, go_router, flutter_bloc, home_widget, flutter_secure_storage, Firebase Messaging |
| Backend | FastAPI, SQLAlchemy 2 (async), Alembic **001–018**, Pydantic v2, SlowAPI, pywebpush, firebase-admin |
| Infra | PostgreSQL 16, Docker Compose, Caddy / nginx |
| Auth | JWT (httpOnly cookies + CSRF на web; Bearer на mobile), OAuth PKCE |

## Архитектура

```mermaid
flowchart LR
  subgraph Clients
    Web[Next.js Web]
    Mobile[Flutter Mobile]
  end
  subgraph Edge
    Proxy[Caddy / nginx]
  end
  subgraph App
    API[FastAPI /api/v1]
    WS[WebSocket /ws]
  end
  DB[(PostgreSQL)]
  Push[Web Push / FCM]

  Web --> Proxy
  Mobile --> API
  Mobile --> Push
  Proxy --> Web
  Proxy --> API
  Proxy --> WS
  API --> DB
  WS --> API
  API --> Push
```

Три оси прав: project RBAC · legacy `UserRole.admin` · `platform_role` для `/admin`.  
Workspace `/projects` — только членство. Подробнее: [docs/architecture.md](docs/architecture.md), [docs/security.md](docs/security.md).

```text
takt/
├── backend/     # FastAPI
├── frontend/    # Next.js: / лендинг, /app workspace, /admin
├── mobile/      # Flutter
├── deploy/      # Prod Compose и server-deploy.sh
├── docs/        # architecture, development, security, oauth, release
└── docker-compose.yml
```

Технические имена Docker/БД (`POSTGRES_USER=track`, `COMPOSE_PROJECT_NAME=track`) сохранены для совместимости с volumes — это не название продукта.

## Быстрый запуск

### Docker

```bash
cp .env.example .env
# SECRET_KEY, POSTGRES_PASSWORD, ADMIN_PASSWORD
docker compose up --build -d
```

Откройте http://localhost — вход учёткой `ADMIN_*` из `.env`.

### Локальная разработка

```bash
docker compose up db -d

cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt && alembic upgrade head
uvicorn app.main:app --reload --port 8000

cd frontend && npm ci && npm run dev   # http://localhost:3000

cd mobile && flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
# Android emulator: API_BASE=http://10.0.2.2:8000
```

Переменные: [`.env.example`](.env.example). OAuth: [docs/oauth.md](docs/oauth.md).  
Mobile: [mobile/docs/MOBILE_SETUP.md](mobile/docs/MOBILE_SETUP.md).  
Prod: [deploy/DEPLOY.md](deploy/DEPLOY.md).

Миграции Alembic **001–018** (head `018_rewrite_notification_copy`). При старте backend выполняет `alembic upgrade head`.

Демо изолировано (`projects.is_demo` / `users.is_demo`). Учётка `DEMO_USER_*` только в локальном `.env` / private — **не** в git.  
Сиды: `setup_demo_workspace.py`, `seed_college_demo.py`, `seed_readme_demo.py`.

## Тестирование

```bash
cd backend  && ./.venv/bin/pytest -q && ./.venv/bin/ruff check app tests
cd frontend && npm test && npm run lint && npm run build
cd mobile   && flutter analyze && flutter test
```

E2E (нужны живые frontend + backend): `cd frontend && PW_CHANNEL=chrome npm run test:e2e`.  
CI: [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Подробнее: [docs/development.md](docs/development.md).

## Документация

| Документ | Содержание |
|----------|------------|
| [docs/architecture.md](docs/architecture.md) | Компоненты, API v1, БД, продуктовая модель |
| [docs/development.md](docs/development.md) | Локальная разработка и тесты |
| [docs/security.md](docs/security.md) | RBAC, CSRF, секреты, удаление аккаунта |
| [docs/oauth.md](docs/oauth.md) | Apple / VK ID / Яндекс ID |
| [docs/release.md](docs/release.md) | Mobile / Play / RuStore / App Store |
| [deploy/DEPLOY.md](deploy/DEPLOY.md) | Production Docker, backup, выкат |

## Лицензия

Исходный код принадлежит [@gadzhilaev](https://github.com/gadzhilaev). Production: **https://taktapp.ru**.

**Лицензия:** proprietary / source-available — [`LICENSE`](LICENSE). Код можно просматривать; это не open-source (копирование и коммерческое использование без письменного разрешения запрещены).
