# Takt Mobile — запуск и настройка

## Требования

- Flutter 3.47+ (stable)
- Xcode 16+ (iOS), Android Studio / SDK 34+
- Backend по умолчанию: `https://taktapp.ru`. Локально: `--dart-define=API_BASE=http://127.0.0.1:8000`
- Миграции: `cd backend && alembic upgrade head` (нужна `007_device_push_tokens`)

## Запуск

```bash
cd mobile
flutter pub get
flutter run
# Локальный backend:
# flutter run --dart-define=API_BASE=http://127.0.0.1:8000
# Android Emulator → host: API_BASE=http://10.0.2.2:8000
```

Подпись на устройстве: **Takt**. Иконка — `assets/brand/app_icon_1024.png` (генерируется через `dart run flutter_launcher_icons`).

## Firebase / FCM

Клиент: `firebase_core` + `firebase_messaging` (`lib/core/push/fcm_bootstrap.dart` + `lib/firebase_options.dart`). Без конфигов soft-fail — приложение работает, push нет.

Bundle/package: **`ru.gadzhilaev.takt`**. Проект Firebase: `takt-1ddc4`.

Из корня монорепо (или любого Flutter-проекта) удобнее:

```bash
flutterfire-app configure --project=takt-1ddc4 --yes --platforms=android,ios \
  --ios-bundle-id=ru.gadzhilaev.takt --android-package-name=ru.gadzhilaev.takt
```

(`~/bin/flutterfire-app` сам находит каталог с `pubspec.yaml` / Flutter — обычный `flutterfire` из корня `takt/` падает с `FlutterAppRequiredException`.)

Либо вручную: `cd mobile && flutterfire configure …`

1. Скрипт кладёт `google-services.json` → `android/app/` и `GoogleService-Info.plist` → `ios/Runner/` (**не коммитьте**).
2. На backend:

```env
FCM_ENABLED=true
FIREBASE_CREDENTIALS_FILE=/absolute/path/to/firebase-adminsdk.json
```

5. После логина клиент регистрирует токен: `POST /api/v1/notifications/device-token`; при logout — `DELETE` того же.

## Виджеты

App Group: `group.ru.gadzhilaev.takt` (Runner.entitlements + виджет).

### Android

`TaktWidgetProvider` в манифесте. Snapshot пишется через `home_widget` после загрузки доски.

### iOS

Target **TaktHomeWidget** уже в `Runner.xcodeproj` (скрипт `ios/scripts/add_home_widget.rb`). Исходники: `ios/TaktHomeWidget/`.

Если target пропал:

```bash
cd mobile/ios && ruby scripts/add_home_widget.rb
```

В Xcode проверьте Signing + App Groups для Runner и TaktHomeWidget.

Виджеты **не** хранят JWT. После logout snapshot очищается.

## Deep links

Схема `takt://` (board / task). FCM data может передать `url`, `project_id`, `task_id`.

## Auth

Логин/регистрация возвращают `access_token` + `refresh_token` в теле. Клиент шлёт `Authorization: Bearer …` (CSRF для Bearer не требуется).

## Store metadata

Черновик текстов для App Store / Google Play: [`../store/metadata.md`](../store/metadata.md).

## Демо

`demo@example.com` — см. `.env` / `~/Documents/private/takt/correspondence/demo-credentials.md`.
