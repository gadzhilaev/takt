# Архитектура frontend (Next.js 14)

## Маршруты

| URL | Назначение |
|-----|------------|
| `/` | Публичный лендинг (RSC). Authed → `/app/projects` |
| `/login`, `/register` | Auth + OAuth (VK / Яндекс) |
| `/change-password` | Принудительная смена пароля |
| `/app/*` | Workspace: проекты, Kanban, профиль |
| `/admin/*` | Platform admin (API `/api/v1/platform`) |
| `/app/admin` | Workspace users (API `/api/v1/admin`) — **не** platform |

Legacy пути (`/projects`, `/board`, `/report`, …) редиректятся на `/app/*` (`next.config.mjs`).

Канон путей в коде: `src/lib/paths.ts`.

## Слои UI

```text
frontend/src/
├── app/                 # App Router pages
├── components/          # UI: kanban, shell, drawers, landing, ui/*
├── lib/                 # api.ts, paths, tokens helpers
├── hooks/
├── middleware.ts        # cookie JWT exp check (без crypto verify)
└── types/
```

- **Server Components:** лендинг, metadata, redirect-страницы.  
- **Client:** почти весь продуктовый UI (`"use client"`).  
- **Состояние:** TanStack Query (`["me"]`, `["projects"]`, board queries) + локальный `useState`. Глобального Redux/Zustand нет.  
- **API:** `lib/api.ts` — `fetch` + `credentials: "include"` + CSRF из cookie.

## Дизайн-система

Токены: `src/app/globals.css` (CSS variables) + Tailwind.  
Бренд: `frontend/public/brand/*.svg`, компонент `BrandLogo`.  
Акцент продукта: `#315F72` (не indigo-dashboard паттерны).

## Крупные модули

`components/kanban-board.tsx` — доска, DnD, мутации. Дальнейший split (board-data / column / dnd) возможен поэтапно; сейчас стабилен и покрыт E2E.

## Тесты

- Vitest: `src/lib/*.test.ts`  
- Playwright: `e2e/` (нужны живые backend+frontend)
