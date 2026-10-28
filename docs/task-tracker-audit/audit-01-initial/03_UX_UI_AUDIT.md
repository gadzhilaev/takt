# 03. UX/UI аудит

Перспектива: пользователь впервые открыл приложение.  
Опора: код UI + практическая сессия в браузере (login → board → admin → list → report).

## 1. Первое впечатление

| Экран | Наблюдение | Тип |
|-------|------------|-----|
| Login | Чистая форма, понятный copy «нет доступа — к админу». Хороший старт. | ок |
| Board после входа | Пустой тёмный экран: заголовок «Доска», кнопка «Экспорт», **нет колонок и empty-state CTA**. Выглядит как «сломалось», не как «пусто». | **подтверждённый дефект** (statuses 500) + UX gap empty/error |
| Admin | Понятная таблица пользователей + форма создания. Самый зрелый экран. | ок |
| List / Report | «Загрузка…» без прогресса и без ошибки. | **подтверждённый дефект** |

Скриншоты: `screenshots/01-board-empty-statuses-500.png`, `03-list-stuck-loading.png`, `04-report-stuck-loading.png`, `02-admin-users-ok.png`.

## 2. Навигация и структура

**Что хорошо**

- Горизонтальная навигация с иконками: Доска / Список / Мои / Отчёт / Профиль
- Mobile secondary nav (`md:hidden`) в `app-shell.tsx`
- Admin скрыт для non-admin

**Проблемы**

| Проблема | Где | Severity |
|----------|-----|----------|
| Нет «домашнего» overview (что делать сегодня) | нет маршрута | P1 product |
| «Мои задачи» и «Профиль» оба с иконкой User — путаница | `app-shell.tsx` nav | P2 |
| Нет индикатора непрочитанных / inbox | — | P1 target |
| Нет глобального поиска в header | — | P1 |
| Brand «Трекер задач» generic; team name из settings не в шапке | shell vs TeamSettings | P2 |
| Deep link на задачу отсутствует | drawer state only | P0 product |

## 3. Создание задачи

Код: quick-add в колонке + hotkey `C` (`kanban-board.tsx`).

| Находка | Severity | Тип |
|---------|----------|-----|
| Сейчас создать нельзя (statuses/tasks 500) | P0 | confirmed |
| Quick-add — только title; нет assignee/priority/due при создании | P1 | UX gap |
| Форма без кнопки «Создать» (только Enter) — неочевидно | P2 | UX |
| После открытия quick-add нет Escape/cancel UI | P2 | UX |
| Hotkey `C` не документирован в UI (кроме текста на `/my`) | P2 | discoverability |
| Нет command palette / `N` create как в Linear | P1 | target |

## 4. Kanban

| Находка | Файл | Severity | Тип |
|---------|------|----------|-----|
| Колонки не рендерятся при ошибке API | kanban-board | P0 | confirmed |
| Drop только на колонку; reorder внутри колонки не работает | `onDragEnd` | P1 | code |
| Нет DragOverlay (ghost) — слабая визуальная обратная связь | kanban-board | P2 | UX |
| Click vs drag: activation distance 8px — ок | sensors | ок | |
| TouchSensor delay 250ms — приемлемо для mobile | sensors | ок | |
| Карточка целиком draggable + onClick open — риск конфликтов | task-card | P2 | UX |
| Нет фильтров над доской | board page | P1 | UX |
| Экспорт на доске при сломанном API бесполезен | board page | P0 now | |

## 5. Карточка и drawer

**Карточка (`task-card.tsx`)** — компактная: title, priority chip, due (overdue red), labels, avatars, checklist ratio. Визуально близко к Linear/YouGile cards.

**Drawer (`task-drawer.tsx`)** — главный UX-разрыв продукта:

| Есть | Нет (хотя API/модель есть) |
|------|----------------------------|
| title autosave | assignees |
| description onBlur | due date |
| status select | labels |
| priority select | comments |
| | checklist |
| | attachments |
| | activity |
| | delete / archive |
| | copy link |
| | keyboard Esc (есть кнопка X) |

Дополнительно:

- Autosave title через `useEffect` + `patch` в deps — риск лишних запросов/циклов (**гипотеза**, не профилировали)
- Description «можно HTML» без preview — вводит в заблуждение
- Нет optimistic UI / toast «сохранено» / ошибки сохранения

## 6. Список / Мои задачи

| Экран | Проблема | Severity |
|-------|----------|----------|
| List | Нет клика по строке → задача | P0 UX |
| List | Нет сортировки/фильтров/поиска | P1 |
| List | При ошибке — empty/loading без текста ошибки | P0 |
| My | Тот же flat list без open | P0 |
| My | Empty state hint про `C` полезен | ок |

## 7. Отчёт

UI выглядит продуктово (KPI cards, charts, Excel) — `report/page.tsx`.  
Сейчас не открывается; плюс `isLoading \|\| !data` прячет ошибку навсегда.

## 8. Визуальная система

| Аспект | Оценка |
|--------|--------|
| Палитра | Indigo + slate, dark mode — аккуратно, близко к «AI default indigo», но консистентно |
| Типографика | System/Tailwind sans — читаемо, не «брендово» |
| Отступы/radius | rounded-xl/lg — единообразно |
| UI kit | Только `Button` + `Input` — мало primitives (Select/Dialog/Toast/Dropdown отсутствуют). В `package.json` много неиспользуемых `@radix-ui/*`, `@dnd-kit/sortable` |
| Состояния | Loading текст; нет skeleton/spinner/error/empty illustrations |
| Accessibility | Частично: aria на theme/logout/close; password toggle есть. Drawer без focus trap/Esc (**гипотеза** по коду) |
| Dark mode | **Дефект по коду:** `next-themes` пишет `class` на `<html>`, Tailwind без `darkMode: "class"` — переключатель Луна/Солнце не переключает `dark:` утилиты |
| Шрифт | Geist подключён переменной в `layout.tsx`, но `font-sans`/globals не мапят на Geist — фактически system/Arial |
| Avatar size | `UserAvatar` для `<img>` использует динамический `h-${size}` — JIT Tailwind такие классы не генерирует; initials-путь через inline style ок |

## 9. Адаптив и клавиатура

- Board: horizontal scroll + snap колонок — задумано под mobile
- Header dual nav — ок
- Не проверено на реальном телефоне в этой сессии (**не проверена**)
- Hotkeys: только `C`; нет `Esc`, `/` search, `←/→` columns

## 10. Что переработать vs улучшить

### Полностью переработать (product surface)

1. **Task detail** — drawer → полноценная панель/страница (Linear-style): свойства, комментарии, чеклист, активность, linkable URL
2. **Error/empty/loading system** — единый слой
3. **Board chrome** — фильтры, поиск, create, view switcher

### Улучшить без rewrite

1. Admin users (уже сильный) — но: debounce поиска; после create `copyLogin` рискует копировать пустой email (form reset); нет UI для CSV/reset-password из API
2. Login / change-password — показать Zod field errors (сейчас только submit error)
3. Task card visual language
4. App shell navigation (дополнить, не выкидывать)
5. Report layout после фикса API
6. `darkMode: "class"` + маппинг Geist; починить `UserAvatar` sizes
7. Description: сохранять и при закрытии drawer, не только onBlur

### Не трогать без нужды

- Auth cookie+CSRF модель
- Tailwind + TanStack Query подход
- dnd-kit как библиотека (чинить поведение, не менять стек)
