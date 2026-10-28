# Финальная полировка (исторический документ)

> Продукт официально называется **Takt**. Документ сохранён как журнал работ до ребрендинга репозитория; см. `docs/TAKT_REBRANDING.md`, `AGENTS.md`.

Дата: 2026-10-28.  
Аудиты `audit-01/02/03` не изменялись. Commit / push / deploy не выполнялись.

## Что исправлено

### Мобильный Kanban (высокий приоритет)
- На `<768px` — **одна колонка** на весь экран, вкладки статусов + «Назад/Далее».
- Карточки на полную ширину, без обрезанных заголовков соседних колонок.
- Смена статуса через **select на карточке** (без touch-DnD → вертикальный скролл не ломается).
- Desktop (`≥768px`) — прежний multi-column Kanban с pointer DnD.

### Отчёты
- Pie/donut больше не «пропадает»: явная высота `ResponsiveContainer` (раньше flex/% давал height=0 → только легенда).
- Donut с `innerRadius`, контрастные цвета, legend с процентами; light/dark и mobile без горизонтального overflow.

### Основные сценарии
- Фильтры доски и списка **в URL** (`q`/`priority`/`assignee`, `search`/`sort`) — ссылку можно шарить.
- «Создать» не упирается в `/projects` без id: редирект на default/первый проект + `?create=1`.
- Aria-label у мобильной кнопки «Создать».

### Качество
- API 401 без сессии (тест).
- E2E: core flow, mobile status move, URL filters, API move/patch.

## Что уже работало и не трогали
- Auth (cookies/CSRF), права проектов, комментарии/чеклисты/подзадачи/история.
- Desktop DnD, страница задачи, «Мои», обзор-сводка, Excel export.
- Исправление stale assignees / nested status после move (из предыдущего прохода).

## Изменённые файлы
- `frontend/src/components/kanban-board.tsx`
- `frontend/src/components/task-card.tsx`
- `frontend/src/components/report-charts.tsx`
- `frontend/src/components/app-shell.tsx`
- `frontend/src/hooks/use-media-query.ts` *(новый)*
- `frontend/src/app/(app)/projects/[id]/page.tsx`
- `frontend/src/app/(app)/projects/page.tsx`
- `frontend/src/app/(app)/list/page.tsx`
- `frontend/src/app/(app)/report/page.tsx`
- `frontend/e2e/core-flow.spec.ts`
- `backend/tests/test_auth.py`
- `docs/TRACK_FINAL_POLISH.md`, `docs/TRACK_FINAL_POLISH_screenshots/` (7 шт.)

## Результаты тестов

| Набор | Результат |
|-------|-----------|
| vitest (`chart-utils`) | 9 passed |
| backend pytest | 14 passed |
| Playwright E2E (`PW_CHANNEL=chrome`) | **4 passed** |
| `next lint` | 1 pre-existing warning (`tasks/[id]` useMemo) |

Сценарии, реально прогнанные: create→assign→due→my→complete; mobile status via select; list URL filters; API move/patch; 401 unauthenticated; screenshots mobile 320/390/430 + report light/dark.

## Что осталось и почему
- Полный bundle Playwright Chromium не скачан (E2E через system Chrome) — сеть/lock; на CI лучше `npx playwright install`.
- Предупреждение eslint в `tasks/[id]` — вне scope текущей полировки.
- GitHub Sync / крупные новые подсистемы — не требуются критерием готовности.
- Visual-regression CI нет.

## Готовность к production

**Функционально — да** для целевого сценария преподавателей/сотрудников: создать → назначить → найти → сменить статус (desktop DnD / mobile select) → обсудить → завершить → увидеть в отчётах, на desktop и телефоне.

Перед выкладкой: `SEED_DEMO_DATA=false`, сильные секреты, HTTPS, прогон E2E против staging, ручная проверка pie на реальных данных периода.
