# Архив

Исторические аудиты (01–03), `TRACK_FINAL_POLISH`, `ux-polish-final`, `TAKT_REBRANDING`, `CROSS_PLATFORM_PLAN` и старые screenshot-каталоги **удалены** при уплотнении документации (2026-10-30): они дублировали уже принятые решения или устарели относительно кода.

Актуальные документы: [`../README.md`](../README.md), [`../../AGENTS.md`](../../AGENTS.md).  
Архитектурные решения сохранены как ADR: [`../decisions/`](../decisions/).

Полезные зафиксированные выводы из истории:

- Продукт = простой Kanban; report/dashboard UI не возвращать без запроса (ADR 0004).
- Технические id `track` в Docker/БД сохранены ради volumes (ADR 0001).
- Dual auth cookies + Bearer (ADR 0002); три оси RBAC (ADR 0003).
- Apple Sign In только mobile (ADR 0005).
- Flutter-клиент реализован в `mobile/` (план «ещё не начинать» устарел).

Полные тексты аудитов при необходимости — в git history до уплотнения docs.
