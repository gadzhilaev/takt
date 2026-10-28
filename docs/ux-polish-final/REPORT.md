# UX polish final (post audit-01/02/03)

Дата: 2026-10-28. Audit-папки не изменялись. Commit/push/deploy не выполнялись.

## Исправлено

- **Обзор**: компактные карточки «Просрочено / Сегодня / Ждут проверки» с быстрым переходом к спискам.
- **Kanban**: адаптивные колонки (snap на mobile, flex на xl), ручка DnD, быстрое «готово» на карточке, подсказка прокрутки.
- **Страница задачи**: параметры сверху на mobile / справа на desktop; плотнее блоки; явная кнопка «Отметить выполненной» (+ sticky на mobile); комментарии/чеклист/подзадачи с label и touch ≥44px.
- **Отчёты**: pad для 1 точки на bar-chart; `avg_days` → «—» / «&lt; 1»; проценты в legend pie; пустые состояния.
- **Назначение исполнителей**: PATCH сохранял assignees в БД, но ответ отдавал `[]` из‑за stale identity map — `get_task(..., populate_existing=True)` + flush после replace.
- **Login**: `method="post"` чтобы пароль не попадал в URL при сбое JS.
- **A11y/mobile**: 16px fields ≤430px, focus ring, muted-fg контраст, mobile nav 52px, scroll-padding под клавиатуру/нижнюю панель.
- **Тесты**: vitest chart-utils; Playwright E2E core flow + API move/patch; backend patch persistence; rate-limit выключен при `ENV=test`.

## Проверено вручную

- Desktop light/dark: обзор, kanban, задача, отчёты.
- Mobile 320 / 390 / 430: обзор, kanban (горизонтальный скролл колонок), задача, «Мои».
- Сценарий готовности: создать → назначить → срок → «Мои» → отметить выполненной (E2E + ручной API).

## Тесты (один прогон)

| Набор | Результат |
|-------|-----------|
| frontend vitest | 9 passed |
| backend pytest | 13 passed |
| Playwright E2E (`PW_CHANNEL=chrome`) | 2 passed |

## Скриншоты (11)

`docs/ux-polish-final/screenshots/` — home/kanban/task/report light+dark, mobile home/kanban/task/my.

## Осталось (неблокирующее)

- Полный download Playwright Chromium bundle (E2E идёт через system Chrome).
- DnD на touch можно ещё сгладить на очень узких экранах (сейчас delay 200ms).
- Pie в dark иногда слабо читается без легенды — легенда с % уже есть.
- Нет отдельного visual-regression CI.
