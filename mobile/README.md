# Takt Mobile

Flutter-клиент продукта **Takt**: проекты, Kanban-доска, мои задачи, уведомления, профиль, home widgets.

| | |
| --- | --- |
| Package / Bundle | `ru.gadzhilaev.takt` |
| API (release) | `https://taktapp.ru` |
| Auth | Bearer JWT; OAuth VK / Яндекс / Apple |

## Запуск

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
# Android emulator: API_BASE=http://10.0.2.2:8000
```

Без `API_BASE` клиент ходит на production.

## Документация

- Настройка Firebase, виджетов, deep links: [docs/MOBILE_SETUP.md](docs/MOBILE_SETUP.md)
- Локальная разработка монорепо: [../docs/development.md](../docs/development.md)
- Релиз / подпись Play + RuStore / App Store: [../docs/release.md](../docs/release.md)
- Тексты сторов: [store/metadata.md](store/metadata.md)
- Архитектура и API: [../docs/architecture.md](../docs/architecture.md)
