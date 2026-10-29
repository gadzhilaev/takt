# Административные панели

## Platform admin (`/admin`)

- Требует `platform_role` ≥ moderator/admin (точный минимум зависит от эндпоинта)  
- Пользователи, модерация, analytics, system, settings (в т.ч. OAuth toggles)  
- API: `/api/v1/platform/*`

## Workspace admin (`/app/admin`)

- Управление пользователями в контексте «команды» (legacy `/api/v1/admin`)  
- Не путать с platform console  

Project admin — роль **внутри проекта**, не URL `/admin`.
