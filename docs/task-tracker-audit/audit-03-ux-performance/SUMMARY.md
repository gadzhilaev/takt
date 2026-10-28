# Audit 03 — UX + performance

Дата: 2026-10-28  
База: [audit-01](../audit-01-initial/), [audit-02](../audit-02-after-redesign/) (не перезаписывались)  
Код приложения изменён; commit/push/deploy **не** выполнялись.

## Цель

Сделать трекер понятным за 10–15 секунд (в т.ч. для преподавателей 40–65+), починить светлую тему и mobile, закрыть дефекты audit-02, ускорить отклик.

## Что сделано

1. **Backend bugs:** fresh nested `status` после move; агрегация `by_status`; `comment_count` / subtask stats в list; формула `% в срок`; регрессионные тесты.
2. **Design tokens** для light/dark; карточки и поля на `var(--surface)`, не «тёмные плитки» на светлом фоне.
3. **UX-упрощение:** подписи в меню, кнопка «Создать задачу», «Пользователи» вместо «Админка», чекбоксы исполнителей, понятные лейблы карточки задачи.
4. **Mobile:** нижняя навигация + FAB «Создать», горизонтальный Kanban со snap, фильтры сворачиваются.
5. **Отчёты:** pie по статусам с агрегацией; bar «закрыто по дням»; dynamic import Recharts.
6. **Perf:** QueryClient `staleTime` / меньше refetch; report First Load **117 → 5.3 kB**.
7. **`docs/CROSS_PLATFORM_PLAN.md`** — план Flutter-клиентов без реализации.

## Короткий вердикт

Продукт заметно понятнее и стабильнее для демо. Light/dark и phone-nav проверены в браузере. Остаётся polish (контраст dark cards, bar chart на 1 точке, a11y checkbox quirks) и auth dual-mode для native.
