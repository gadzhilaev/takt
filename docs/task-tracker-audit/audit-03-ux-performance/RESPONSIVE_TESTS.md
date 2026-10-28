# Responsive / themes — матрица проверок

Проверка в Cursor browser + device metrics. Не на каждый cell отдельный скрин — см. [screenshots/](screenshots/) и текст ниже.

## Ширины

| Width | Результат |
|-------|-----------|
| 320–390 | Bottom nav виден; обзор стеком; Kanban горизонтальный scroll + hint; фильтры доски сворачиваются |
| 430 | То же |
| 768 | Sidebar ещё скрыт (breakpoint `lg`), bottom nav |
| 1024+ | Sidebar desktop; bottom nav скрыт |
| 1440 | Широкий контент `max-w-[1600px]` |

Скрины mobile: `08-home-mobile-390.png`, `09-kanban-mobile-390.png`.

## Темы × экраны

| Экран | Light | Dark | System |
|-------|-------|------|--------|
| Обзор | ✓ скрин 01 | ✓ скрин 06 | ✓ меню есть; следует OS |
| Проекты / Kanban | ✓ 02 | ✓ (визуально при dark class) | ✓ |
| Карточка задачи | ✓ 03 | ✓ (переключено) | ✓ |
| Мои | ✓ (навигация) | ✓ 07 | ✓ |
| Список | ✓ (навигация + код tokens) | ✓ | ✓ |
| Отчёты | ✓ 04 | ✓ 05 | ✓ |
| Пользователи | ✓ (навигация) | ✓ | ✓ |
| Inbox | ✓ (empty state без регрессии) | ✓ | ✓ |
| Login | ✓ tokens | ✓ | ✓ |
| Модалки/меню темы | ✓ Светлая/Тёмная/Системная | ✓ | ✓ |

## Touch / a11y notes

- Hit targets кнопок ≥ 44px (button sizes).
- TouchSensor dnd-kit: delay 200ms.
- Checklist/assignee inputs: в a11y-tree иногда `readonly` у controlled checkbox — поведение клика в UI работает; улучшить native semantics в следующем проходе.
