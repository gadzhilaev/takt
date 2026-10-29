# Takt — визуальный ребрендинг

> **Частично устарело.** Каталога `src/app/(app)` нет — канон `/app/*`. Актуальные docs: [`architecture/frontend.md`](architecture/frontend.md), [`archive/README.md`](archive/README.md).

Дата: 2026-10-28.  
База: `docs/TRACK_FINAL_POLISH.md` (функциональность не пересматривалась).  
Commit / push / deploy **не** выполнялись.

## Цель

Продуктовое имя в UI: **Takt**. Дизайн-система доведена до плотного B2B SaaS (Linear / GitHub Projects по плотности и сдержанности), без шаблонного «AI-dashboard» вида. Технические идентификаторы, API, маршруты и схема БД **не** переименовывались.

## Брендинг

| Элемент | Решение |
| --- | --- |
| Название в UI | Takt (логин, sidebar, metadata) |
| Знак | Официальный SVG `public/brand/takt-symbol.svg` (`BrandMark`) |
| Wordmark | `takt-wordmark.svg` (+ `*-on-dark` для тёмной темы) |
| Полный логотип | `takt-logo.svg` / `takt-logo-on-dark.svg` (`BrandLogo`, sidebar + login) |
| Favicon | `frontend/public/favicon.svg` (= знак) |
| Не трогали | package name, DB, `/api/v1/*`, пути `/projects`, `/tasks`, … |

Исходники — утверждённые файлы заказчика; не перерисовывать. Варианты on-dark меняют только заливку надписи (`#19212D`/`#18212C` → `#F2F5F7`).

## Дизайн-токены

Источник: `frontend/src/app/globals.css` + `tailwind.config.ts`.

**Светлая тема**

- фон `#F7F8FA`, поверхности `#FFFFFF` / `#F1F3F5`
- текст `#202938`, muted `#667485`, границы `#DCE2E7`
- акцент `#315F72`, soft `#E8EEF1`

**Тёмная тема**

- графит `#12151A` / `#1A1E24` / `#22272E`
- акцент `#5A8FA3` (тот же характер бренда)
- без лишних теней

**Система**

- шрифт Inter (`next/font`), единая шкала радиусов (`--radius*`), высот контролов (`--control-h*`)
- утилиты: `.surface-panel`, `.surface-card`, `.field`, `.nav-link`, `.stat-tile`, `.section-label`
- приоритеты/статусы — мягкие soft-чипы, не плашки «на весь экран»

Отказ от: фиолетовых акцентов UI, крупных `rounded-2xl`, теней вокруг каждого блока, декоративных градиентов.

## Экраны

Приведены к токенам: sidebar / top bar, обзор, мои задачи, список, Kanban (desktop DnD + mobile одна колонка), карточка задачи, создание/редактирование, отчёты, пользователи/настройки, мобильная навигация.

Kanban: компактные карточки (`TaskCard`), тонкая цветная кромка колонки (2px), на mobile — вкладки + select статуса.

## Проверки

| Проверка | Результат |
| --- | --- |
| `npm test` (vitest) | 9 passed |
| `npm run lint` | warning hooks в `tasks/[id]` (существовало ранее) |
| `npx tsc --noEmit` / `npm run build` | OK |
| backend `pytest` | 14 passed |
| Playwright `core-flow.spec.ts` | 4 сценария OK |
| Скриншоты | 12 шт. в `docs/screenshots/takt-rebrand/` |

Скриншоты: login/home/kanban/list/report (desktop light), home/kanban (desktop dark), home/kanban/my (mobile light), login/report (mobile dark).

Скрипт захвата: `frontend/e2e/takt-screenshots.spec.ts` (`PW_CHANNEL=chrome`).

## Ключевые файлы

- `frontend/src/components/brand-mark.tsx`
- `frontend/public/favicon.svg`
- `frontend/src/app/globals.css`, `layout.tsx`, `tailwind.config.ts`
- `frontend/src/components/app-shell.tsx`, `ui/button.tsx`, `task-card.tsx`, `kanban-board.tsx`
- страницы `(app)/home|my|list|report|projects|tasks|admin`, `login`

## Ограничения

1. **GitHub-репозиторий** переименован в `gadzhilaev/takt`. Технические идентификаторы БД/Docker (`POSTGRES_*`, volume `track_pgdata`, Python package `app`) сохранены для совместимости.
2. **Цвета проектов и статусов** приходят из БД (точки проектов, кромки колонок) — не унифицированы под палитру Takt целиком.
3. После `npm run build` нужен **рестарт** Next (`dev`/`start`): иначе 404 на `_next/static/chunks` и «мёртвый» login (форма уходит на `#`).
4. E2E опирается на system Chrome (`PW_CHANNEL=chrome`), не на скачанный Chromium Playwright.
5. Функциональные подсистемы не добавлялись; аудит-файлы `audit-*` не правились.

## Критерий готовности

Takt читается как цельный продукт с узнаваемым знаком и сдержанной палитрой; сценарии из финальной полировки (фильтры URL, DnD, mobile Kanban, отчёты, права) сохранены.
