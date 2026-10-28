# Test results — audit-03

## Backend pytest

```text
PYTHONPATH=. pytest tests/test_serializers_and_reports.py tests/test_tasks.py
9 passed
```

Новые/расширенные:

- `test_move_returns_fresh_nested_status`
- `test_list_comment_count`
- `test_reports_and_export_ok` — unique `by_status` names; `on_time_pct` null|number

## Runtime API (после фикса)

| Проверка | Результат |
|----------|-----------|
| Move nested status | `status.name` совпадает с целевым сразу в ответе move |
| `by_status` | уникальные имена, суммы по проектам |
| `comment_count` в list | ≥1 у задач с комментариями |
| Reports + Excel | 200 |
| Member admin 403 | без регрессии |

## Browser

- Light: home, kanban Backend API (светлые карточки), task detail, report (pie заполнен).
- Dark: report, my; home/report dark surfaces.
- Mobile 390: bottom nav + create; kanban column snap + «Листайте колонки…».
- Theme menu: Светлая / Тёмная / Системная.

## Production build

`next build` успешен после правок типов/`dynamic` charts.

## Не покрыто этим прогоном

- Полный touch DnD e2e на телефоне.
- Visual regression automated.
- Load test 1000 задач.
