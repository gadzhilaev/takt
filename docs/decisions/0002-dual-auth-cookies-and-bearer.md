# ADR 0002 — Dual-mode auth: cookies + Bearer

- **Статус:** принято

## Контекст

Web удобен с httpOnly cookies; Flutter/native — с Bearer в secure storage.

## Решение

Один JWT-контур: access/refresh. Web выставляет cookies (+ CSRF). Mobile принимает токены в JSON и шлёт Bearer. `verify_csrf` пропускает Bearer.

## Последствия

- Один `get_current_user` обслуживает оба клиента.  
- Нельзя полагаться только на SameSite для mobile WebView без анализа cookie policy.
