# Performance

## Метод

- API latency: 5× `curl`/urllib на живом backend (dev).
- Frontend: `next build` First Load JS до/после (production bundle).
- Не оптимизировали «наугад»: только подтверждённые узкие места.

## API (локальный Postgres + uvicorn)

| Endpoint | avg | min–max |
|----------|-----|---------|
| `GET /api/v1/auth/me` | ~1.9 ms | 1.6–3.0 |
| `GET /api/v1/tasks?page_size=100` | ~12 ms | 7–24 |
| `GET /api/v1/projects` | ~14 ms | 6–27 |
| `GET /api/v1/reports?preset=month` | ~19 ms | 14–29 |

Узких мест SQL на текущем объёме (~18 задач) не выявлено. Добавлены batch-запросы `comment_counts` / `subtask_stats` вместо N+1 в list.

## Frontend bundle (production)

| Route | Было (audit-02 era) | Стало |
|-------|---------------------|-------|
| `/report` First Load | **~223 kB** (Recharts в основном чанке, page ~117 kB) | **~111 kB** shared; page **5.34 kB** + lazy charts |
| Shared First Load | ~87.5 kB | ~87.5 kB |
| `/home` | — | 3.86 kB / 132 kB FL |
| `/projects/[id]` | — | 22.5 kB / 142 kB FL |

Изменение: `dynamic(() => import(report-charts), { ssr: false })`.

## React Query

До: дефолтный client → частый refetch on focus.  
После: `staleTime: 20s`, `refetchOnWindowFocus: false`, `retry: 1`; точечно выше на `me`/`projects`/`report`.

## Что не трогали

- DnD virtualization на 1000+ карточек (нет нагрузки в демо).
- SQL индексы сверх текущих (latency уже низкая).
- Dev HMR время — не метрика продукта.
