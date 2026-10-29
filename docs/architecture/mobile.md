# Архитектура mobile (Flutter)

## Структура

```text
mobile/lib/
├── main.dart / app.dart     # DI: RepositoryProvider + Cubit
├── core/                    # ApiClient, router, theme, tokens, FCM
├── features/
│   ├── auth/                # data + presentation (+ cubit)
│   ├── board/               # data + cubit + presentation
│   ├── projects/, my_tasks/, notifications/, profile/
│   └── widget_sync/         # snapshot для home widgets
└── shared/                  # models, widgets (Takt UI)
```

Отдельного слоя `domain/` нет — для текущего размера приложения это осознанно (KISS). Репозитории в `features/*/data/` — единственное место HTTP (`Dio`).

## State management

- `AuthCubit`, `BoardCubit` — глобально через `MultiBlocProvider`  
- Остальные экраны: `StatefulWidget` + `Repository`  
- `OAuthRepository` регистрируется в `app.dart` (не создаётся в виджете)

Виджеты **не** вызывают `dio` напрямую. `ApiClient` в UI допускается только для `messageFromError`.

## Auth и OAuth

- Токены в `TokenStorage` (secure storage)  
- Bearer на всех запросах; CSRF не нужен  
- OAuth: старт через API → browser/`url_launcher` → deep link `takt://oauth/callback`  
- Apple — в mobile UI; на web кнопки Apple нет

## Push и виджеты

- FCM: soft-fail без native configs  
- Home widgets: App Group `group.ru.gadzhilaev.takt`, snapshot v3; **JWT в виджет не пишется**  
- Deep links: `takt://`, FCM data, tap по виджету

## Конфиг API

`--dart-define=API_BASE=...`. По умолчанию debug тоже может указывать на production — для локальной разработки задавайте API_BASE явно.

См. [`../../mobile/docs/MOBILE_SETUP.md`](../../mobile/docs/MOBILE_SETUP.md).
