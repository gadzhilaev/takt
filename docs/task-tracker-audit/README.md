# История аудитов (продукт: Takt)

> **Архив.** Не источник истины по текущей архитектуре — см. [`../archive/README.md`](../archive/README.md) и [`../architecture/`](../architecture/).

Исторические материалы аудитов. Продукт официально называется **Takt**; тексты аудитов могут ещё упоминать прежнее рабочее имя. Каждый аудит хранится в отдельной папке; предыдущие материалы **не перезаписываются**.

| Аудит | Дата | Причина | Краткий результат | Документы |
|-------|------|---------|-------------------|-----------|
| [audit-01-initial](audit-01-initial/) | 2026-10-28 | Первый полный аудит до переработки | P0-блокеры: statuses/tasks/reports 500, пустая доска, зависание list/report; нет проектов; тёмная тема фактически не работает | [01](audit-01-initial/01_CURRENT_STATE.md) · [02](audit-01-initial/02_FUNCTIONAL_AUDIT.md) · [03](audit-01-initial/03_UX_UI_AUDIT.md) · [04](audit-01-initial/04_TARGET_PRODUCT.md) · [05](audit-01-initial/05_ARCHITECTURE.md) · [06](audit-01-initial/06_IMPLEMENTATION_PLAN.md) · [07](audit-01-initial/07_TEST_STRATEGY.md) · [screenshots](audit-01-initial/screenshots/) |
| [audit-02-after-redesign](audit-02-after-redesign/) | 2026-10-28 | Повторный аудит после redesign + projects + demo seed | P0 runtime-блокеры сняты; 4 проекта / 18 задач; Kanban/list/my/report/admin/task detail работают; остались дефекты serializer move, агрегация отчёта, часть UX | [01](audit-02-after-redesign/01_CURRENT_STATE.md) · [02](audit-02-after-redesign/02_FUNCTIONAL_AUDIT.md) · [03](audit-02-after-redesign/03_UX_UI_AUDIT.md) · [04](audit-02-after-redesign/04_IMPLEMENTED_FEATURES.md) · [05](audit-02-after-redesign/05_REMAINING_ISSUES.md) · [06](audit-02-after-redesign/06_TEST_RESULTS.md) · [screenshots](audit-02-after-redesign/screenshots/) |
| [audit-03-ux-performance](audit-03-ux-performance/) | 2026-10-28 | UX для нетехнических пользователей + light/dark/mobile + баги audit-02 + perf | Nested status/by_status/comment_count исправлены; понятный shell + mobile nav; light cards; report charts; report JS 117→5 kB; план Flutter | [SUMMARY](audit-03-ux-performance/SUMMARY.md) · [UX](audit-03-ux-performance/UX_CHANGES.md) · [PERF](audit-03-ux-performance/PERFORMANCE.md) · [RESPONSIVE](audit-03-ux-performance/RESPONSIVE_TESTS.md) · [TESTS](audit-03-ux-performance/TEST_RESULTS.md) · [screenshots](audit-03-ux-performance/screenshots/) |

Связанный документ: [docs/CROSS_PLATFORM_PLAN.md](../CROSS_PLATFORM_PLAN.md).

## Правила ведения истории

1. Новый аудит → новая папка `audit-NN-<slug>/` (`audit-04-…` и далее).
2. Документы и скриншоты предыдущих аудитов **не удалять и не заменять**.
3. В корневом `README.md` добавлять строку в таблицу с датой, причиной, кратким итогом и ссылками.
4. Скриншоты текущего аудита класть только в `audit-NN-…/screenshots/`.
5. Аудит фиксирует фактическое поведение (браузер + API), а не только наличие кода.
