# 01. Текущее состояние после переработки

Дата аудита: 2026-10-28  
Окружение: PostgreSQL `track-db-1` (:5433, healthy), FastAPI `127.0.0.1:8000`, Next.js `127.0.0.1:3000`  
Метод: браузер (admin), REST API (admin + member), сравнение с [audit-01-initial](../audit-01-initial/)

Код приложения в ходе этого аудита **не менялся**.

## 1. Продукт сейчас

Командный трекер с **несколькими проектами**, per-project статусами и Kanban-досками, списком, «Мои задачи», обзором, отчётами/Excel, inbox уведомлений, карточкой задачи по URL и админкой пользователей.

Стек без изменений: FastAPI + SQLAlchemy async + Postgres 16 + Next.js 14 + TanStack Query + dnd-kit + next-themes.

## 2. Демо-данные (runtime)

| Сущность | Факт |
|----------|------|
| Пользователи | Администратор, Иван Участник, Анна Дизайн |
| Проекты | Общее, Backend API, Мобильное приложение, Разработка сайта |
| Задачи | **18** (seed ~13 + smoke/audit create) |
| По статусам | К выполнению 6 · В работе 4 · На проверке 3 · Готово 3 · Бэклог 2 |
| Закрытые | 3 (`closed_at` заполнен) |
| Просроченные открытые | 3 (по `/api/v1/reports`: metrics.overdue=3; UI «Мои»/«Обзор» показывают те же) |
| Прогресс проектов | Общее 0/3 · Backend API 1/7 · Mobile 1/4 · Сайт 1/4 |

Seed идемпотентен (`seed-demo` повторно не плодит дубликаты — проверено ранее в сессии).

## 3. Что работает (подтверждено браузером + API)

- Auth cookie JWT + CSRF; login admin `ChangeMeAdmin123!`; member `Member123!`
- Навигация shell: Обзор / Проекты / Мои / Список / Отчёты / Админка + список проектов в sidebar
- Home (`/home`): колонки сегодня / просрочено / в работе / на проверке + прогресс проектов
- Projects list и Kanban по проекту (Backend API заполнен)
- List: таблица 18 задач, поиск/сортировка UI
- My: группировка Просрочено / Сегодня / Завтра / Позже / Без срока / Завершено
- Task page `/tasks/{id}`: title, markdown desc, checklist, subtasks UI, comments, activity, status/priority/due/assignees/labels, duplicate/archive/delete/link
- Report: метрики, by employee, recent completed, Excel download 200 (`application/vnd…sheet`, ~12 KB)
- Admin users: список, форма создания, deactivate
- Themes: Светлая / Тёмная / Системная (меню у кнопки «Тема»)
- Notifications API: у member есть упоминание «Audit2 smoke create»; UI inbox у admin пуст (ожидаемо)
- Member → `/api/v1/admin/users` → **403**
- `GET /health` → ok; statuses/tasks больше не отдают 500

Скриншоты: [screenshots/](screenshots/).

## 4. Сравнение с audit-01 одной фразой

| Было (audit-01) | Стало (audit-02) |
|-----------------|------------------|
| Доска пустая, statuses 500 | Доски по проектам с задачами |
| List/Report «Загрузка…» | List и Report с данными |
| Нет проектов | 4 проекта + progress |
| Dark mode не применялся | Light/Dark/System работают |
| Карточка — drawer без URL | Полноценная страница `/tasks/{id}` |
| Нет UI комментариев/чеклистов | Есть на странице задачи |

## 5. Известные дефекты (кратко)

Подробности — в [05_REMAINING_ISSUES.md](05_REMAINING_ISSUES.md).

1. `POST …/tasks/{id}/move`: в ответе `status_id` верный, вложенный `status.name` **устаревший** до следующего GET.
2. `/api/v1/reports` → `metrics.by_status` — список пар без агрегации (дубликаты имён статусов).
3. Счётчик `comment_count` в list может быть 0 при наличии комментариев в detail.
4. UX: в light theme часть полей карточки выглядят «тёмными блоками»; узкий viewport — sidebar/адаптив слабый.
5. Charts на отчёте почти пустые при наличии данных (closed_by_day есть, визуализация слабая).
