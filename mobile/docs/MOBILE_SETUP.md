# Takt Mobile — Firebase, виджеты, deep links

Общий запуск и тесты: [../../docs/development.md](../../docs/development.md).  
Релиз и подпись: [../../docs/release.md](../../docs/release.md).

## Требования

- Flutter 3.47+ (stable), Xcode 16+ (iOS), Android SDK 34+
- Backend: production `https://taktapp.ru` или локально `--dart-define=API_BASE=…`
- Миграции backend до head **016** (нужна как минимум `007_device_push_tokens` для FCM)

## Firebase / FCM

Клиент: `firebase_core` + `firebase_messaging` (`lib/core/push/fcm_bootstrap.dart`, `lib/firebase_options.dart`). Без native-конфигов soft-fail — приложение работает, push нет.

Bundle/package: **`ru.gadzhilaev.takt`**. Проект Firebase: `takt-1ddc4`.

```bash
# из каталога mobile/ (не из корня монорепо)
flutterfire configure --project=takt-1ddc4 --yes --platforms=android,ios \
  --ios-bundle-id=ru.gadzhilaev.takt --android-package-name=ru.gadzhilaev.takt
```

Или helper `flutterfire-app` из PATH — сам находит Flutter-пакет.

1. `google-services.json` → `android/app/`, `GoogleService-Info.plist` → `ios/Runner/` (**не в git**).
2. На backend:

```env
FCM_ENABLED=true
FIREBASE_CREDENTIALS_FILE=/absolute/path/to/firebase-adminsdk.json
```

3. После логина: `POST /api/v1/notifications/device-token`; при logout — `DELETE`.

## Виджеты

App Group: `group.ru.gadzhilaev.takt` (Runner.entitlements + виджет).

- Android: `TaktWidgetProvider`; snapshot через `home_widget` после загрузки доски.
- iOS: target **TaktHomeWidget** в `Runner.xcodeproj` (`ios/scripts/add_home_widget.rb`, исходники `ios/TaktHomeWidget/`).

Виджеты **не** хранят JWT. После logout snapshot очищается.

## Deep links и auth

- Схема `takt://` (board / task / oauth callback).
- FCM data может передать `url`, `project_id`, `task_id`.
- Логин возвращает токены в JSON; клиент шлёт `Authorization: Bearer …` (CSRF не нужен).
- OAuth VK/Яндекс: HTTPS callback → bounce на `takt://`; Apple — нативный Sign in with Apple. См. [../../docs/oauth.md](../../docs/oauth.md).

## Store metadata

Черновик текстов: [`../store/metadata.md`](../store/metadata.md).
