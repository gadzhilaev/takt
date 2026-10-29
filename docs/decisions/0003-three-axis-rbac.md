# ADR 0003 — Три оси RBAC

- **Статус:** принято (эволюционно)

## Контекст

Нужны права внутри проекта, legacy «админ команды» и отдельная платформенная консоль оператора.

## Решение

1. `ProjectMemberRole` — основной ACL проектов/задач.  
2. `UserRole.admin` — legacy global admin для non-demo проектов.  
3. `platform_role` (миграция 012) — `/admin` и `/platform` API.

## Последствия

- Два UI «admin» (`/admin` vs `/app/admin`) — документировать явно.  
- Слияние legacy `UserRole.admin` с `platform_role` — отдельный продуктный шаг, не silent refactor.
