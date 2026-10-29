# Contributing

## Принципы

1. Читать [`AGENTS.md`](../AGENTS.md) и [`AI_PROJECT_CONTEXT.md`](AI_PROJECT_CONTEXT.md).  
2. Не ломать API-контракты и уже применённые миграции.  
3. Не возвращать скрытые сложные UI (отчёты/фильтры) без запроса.  
4. Не коммитить секреты.  
5. Commit / push / deploy — только с явного разрешения владельца репозитория.

## Стиль кода

- Python: Ruff; async SQLAlchemy 2; Pydantic v2  
- TypeScript: ESLint (next lint); Prefers existing patterns  
- Dart: `flutter analyze` clean  
- EditorConfig: [`.editorconfig`](../.editorconfig)  
- Сообщения **новых** коммитов — на русском, без Conventional Commits префиксов; без AI co-authored trailers  

## Организация изменений

- Маленькие PR / коммиты по смыслу  
- Миграции — отдельным коммитом или явно в описании  
- После существенных этапов обновить `docs/AI_PROJECT_CONTEXT.md`  

## Тесты перед сдачей

См. [testing/README.md](testing/README.md). Минимум: релевантный слой (pytest / npm test / flutter test).

## Миграции

```bash
cd backend
alembic revision -m "short_description"
# заполнить upgrade/downgrade
alembic upgrade head
```

Не переписывать уже выкатанные revision на production.
