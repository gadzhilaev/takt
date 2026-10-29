# Документация Takt

Единая точка входа. **Источник истины по поведению — код** (`backend/`, `frontend/`, `mobile/`); документы обновляются после существенных изменений.

Для AI-агентов сначала: [`../AGENTS.md`](../AGENTS.md) и [`AI_PROJECT_CONTEXT.md`](AI_PROJECT_CONTEXT.md).

## Навигация

| Документ | Для кого | О чём |
|----------|----------|--------|
| [architecture/overview.md](architecture/overview.md) | Все | Компоненты, потоки, диаграммы |
| [architecture/backend.md](architecture/backend.md) | Backend | Слои FastAPI, DI, транзакции |
| [architecture/frontend.md](architecture/frontend.md) | Frontend | Next.js маршруты, Query, UI |
| [architecture/mobile.md](architecture/mobile.md) | Mobile | Flutter features, push, widgets |
| [architecture/database.md](architecture/database.md) | Backend / DBA | Сущности, миграции |
| [api/README.md](api/README.md) | Клиенты API | Auth, ресурсы, ошибки |
| [security/README.md](security/README.md) | Security | RBAC, OAuth, секреты |
| [features/](features/) | Product / eng | Возможности продукта |
| [deployment/](deployment/) | DevOps | Local, Docker, prod |
| [testing/](testing/) | QA / eng | Pytest, Vitest, E2E, Flutter |
| [contributing.md](contributing.md) | Contributors | Стиль, PR, миграции |
| [decisions/](decisions/) | Architects | ADR |
| [OAUTH_SETUP.md](OAUTH_SETUP.md) | Ops | Настройка Apple / VK / Яндекс |
| [archive/](archive/) | Историки | Устаревшие аудиты и планы |

## Быстрые ссылки

- Корневой README: [`../README.md`](../README.md)
- Deploy: [`../deploy/DEPLOY.md`](../deploy/DEPLOY.md)
- Mobile setup: [`../mobile/docs/MOBILE_SETUP.md`](../mobile/docs/MOBILE_SETUP.md)
- OpenAPI (локально): `http://localhost:8000/docs`
