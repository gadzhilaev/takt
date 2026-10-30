# Возможности продукта

**Не в основном UI:** богатые web-отчёты и dashboard-фильтры (API `/reports` может существовать).

## Проекты

- Создатель → `ProjectMemberRole.admin`
- Цвет, иконка, описание; архивация
- Роли: admin / member / viewer
- Новые проекты: 4 столбца — К выполнению / В работе / На проверке / Готово
- `is_demo=true` — только участники (системный admin без membership не видит)
- Leave requests (`010`)

API: `/api/v1/projects`. Web: `/app/projects`. Mobile: hub + board.

## Задачи и Kanban

- Столбец = `TaskStatus` (`is_done`, цвет, порядок)
- Задача: title, description, priority, assignees 0..n, labels, due date, checklist, comments
- Создание: `position = min(column) − 1024` (в начало)
- Move: `POST /tasks/{id}/move`
- Удаление: soft-delete; **только автор**
- Web: `KanbanBoard` + task drawer; Mobile: board + form/detail

## Участники и приглашения

- Приглашение по email; поиск пользователей
- In-app inbox (`/invites/mine`)
- SMTP для писем не имитируется, если не настроен — приглашение создаётся в продукте
- Не создавать фиктивные аккаунты с именами реальных людей вне демо

## Уведомления

- In-app: assignment, completion, mentions, invites
- Web Push (VAPID), Mobile FCM
- Тексты assignment: «Вам» + имена в именительном (`ru_names`)

## Home widgets

- Android / iOS (WidgetKit iOS 17+)
- App Group `group.ru.gadzhilaev.takt`
- Snapshot v3; **JWT в виджет не пишется**; после logout snapshot очищается

## Auth email

- Регистрация: OTP на email (`/auth/register/send-code` → `confirm`)
- Смена пароля (в сессии): OTP (`/auth/change-password/*`)
- Сброс забытого пароля: OTP без сессии (`/auth/forgot-password/send-code` → `confirm`); web `/forgot-password`, mobile тот же поток

## OAuth

| Клиент | VK | Яндекс | Apple |
|--------|----|--------|-------|
| Web | да | да | нет |
| Mobile | да | да | да (credentials + политика) |

Настройка: [oauth.md](oauth.md).

## Админ-панели

- **Platform** `/admin` — `platform_role`; пользователи, модерация, analytics, settings
- **Workspace** `/app/admin` — legacy `/api/v1/admin`
- Project admin — роль внутри проекта, не URL `/admin`

## Модерация

Платформенный контур (миграция `012`): reports / blocks / activity через `/api/v1/platform/*`, UI `/admin/moderation`.
