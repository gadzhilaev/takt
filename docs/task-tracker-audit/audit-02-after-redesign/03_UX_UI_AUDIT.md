# 03. UX / UI аудит (после redesign)

Дата: 2026-10-28. Сравнение с [audit-01 UX](../audit-01-initial/03_UX_UI_AUDIT.md).

## 1. Что было в первом аудите

- Пустая доска без колонок (statuses 500).
- List/Report вечная «Загрузка…».
- Dark mode не применялся (`darkMode` class не работал).
- Навигация «Доска / Список / …» без проектов и обзора.
- Карточка — drawer без deep link; нет UI комментариев/чеклистов/assignees.
- Admin выглядел ок на фоне остального.

Скриншоты audit-01 сохранены: [../audit-01-initial/screenshots/](../audit-01-initial/screenshots/).

## 2. Что исправлено и подтверждено

| Тема | Подтверждение |
|------|---------------|
| Светлая тема | [11-home-light](screenshots/11-home-light.png), [10-kanban-light](screenshots/10-kanban-backend-light.png), [12-task-light](screenshots/12-task-detail-light.png) |
| Тёмная тема | [01](screenshots/01-home-dark.png)–[09](screenshots/09-inbox-dark.png) |
| Системная тема | меню «Системная»; [13-task-detail-system](screenshots/13-task-detail-system.png) (иконка laptop) |
| Sidebar + проекты | цветные dots, active project highlight |
| Обзор / Мои / Список / Отчёты | данные вместо spinner |
| Task page | checklist, comments, history, meta sidebar |
| Admin | create user form + table |

## 3. Реализовано, но UX спорный / неправильный

1. **Поля карточки в light theme** — крупные title/input могут выглядеть как тёмные «дыры» на светлом фоне ([12](screenshots/12-task-detail-light.png)).
2. **Kanban light** — колонки светлые, карточки тёмные: контраст резкий, не единый surface language ([10](screenshots/10-kanban-backend-light.png)).
3. **Отчёт charts** — блоки «Закрыто по дням» / «По статусам» выглядят пустыми при ненулевых метриках ([07](screenshots/07-report-dark.png)).
4. **Inbox empty state** корректный для admin, но нет hint «переключитесь в аккаунт с упоминаниями» ([09](screenshots/09-inbox-dark.png)).
5. **Checklist a11y** — чекбоксы в snapshot помечены `readonly` (возможна кастомная реализация без native toggle semantics).
6. **% в срок = 0** у всех в отчёте — выглядит как поломка метрики, даже если данные «честные».

## 4. Проблемы, появившиеся / ставшие заметными после переработки

- Nested `status` stale после move → риск «прыжка» карточки в UI при optimistic update.
- `comment_count` в list расходится с реальными comments.
- Reports `by_status` не агрегирован → будущий chart сломается.
- Узкий viewport: sidebar исчезает/ломает композицию; контент не становится mobile-first ([14-home-mobile-system](screenshots/14-home-mobile-system.png)).
- Больше сущностей (проекты, статусы per-project) → выше риск выбрать «чужой» status_id при API-клиентах.

## 5. Что ещё улучшить в UX/UI

- Единая дизайн-система поверхностей для light (карточки, inputs, title).
- Mobile: drawer nav, компактный Kanban (horizontal columns swipe).
- Empty/error/skeleton states единообразно (сейчас лучше, чем audit-01, но charts/inbox сырые).
- Inline create на доске + toast ошибок сети.
- Визуальный overdue/priority legend.
- Project settings UI (участники, архив, цвет) рядом с доской.
- Отчёт: нормальные chart lib bindings + агрегированные серии.
- Focus states / keyboard: `C` заявлен — проверить discoverability.

## 6. Вердикт UX

Продукт **узнаваем и usable** для desktop admin/demo. Визуально далёк от «пустого 500-экрана» audit-01. До production не хватает polish light theme, mobile и отчётной визуализации.
