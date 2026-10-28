# Takt Mobile — запуск и настройка

## Требования

- Flutter 3.47+ (stable)
- Xcode 16+ (iOS), Android Studio / SDK 34+
- Backend Takt на `http://127.0.0.1:8000` (или `--dart-define=API_BASE=…`)

## Запуск

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
# iOS Simulator: API_BASE=http://127.0.0.1:8000
# Android Emulator: API_BASE=http://10.0.2.2:8000
```

## Firebase / FCM (ручная настройка)

1. Создайте проект Firebase, добавьте Android (`ru.takt.takt_mobile`) и iOS apps.
2. Скачайте `google-services.json` → `mobile/android/app/` (**не коммитьте**).
3. Скачайте `GoogleService-Info.plist` → `mobile/ios/Runner/` (**не коммитьте**).
4. На backend положите service-account JSON вне git и задайте:

```env
FCM_ENABLED=true
FIREBASE_CREDENTIALS_FILE=/absolute/path/to/firebase-adminsdk.json
```

5. Добавьте в `mobile` пакеты `firebase_core` + `firebase_messaging` и инициализацию в `main.dart` (заготовка API: `POST /api/v1/notifications/device-token`).

Без шагов выше in-app уведомления работают, мобильный push — нет.

## Виджеты

### Android

`TaktWidgetProvider` уже в манифесте. После входа и загрузки доски Flutter пишет snapshot через `home_widget`. Добавьте виджет с рабочего стола.

### iOS (Xcode, вручную)

1. File → New → Target → Widget Extension, имя `TaktHomeWidget`.
2. Включите App Group `group.ru.takt.mobile` для Runner и виджета.
3. Замените сгенерированный Swift на `ios/TaktHomeWidget/TaktHomeWidget.swift`.
4. URL scheme `takt` уже планируется для deep link (Info.plist).

Виджеты **не** хранят JWT. После logout snapshot очищается.

## Auth

Логин/регистрация возвращают `access_token` + `refresh_token` в теле ответа. Клиент шлёт `Authorization: Bearer …` (CSRF для Bearer не требуется).

## Демо

`demo@example.com` — см. `.env` / `~/Documents/private/takt/correspondence/demo-credentials.md`.
