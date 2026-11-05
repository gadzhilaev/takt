# Релиз mobile

CI на push — только тесты; **не** деплоит production и **не** публикует в магазины.

## Идентификаторы

| | |
| --- | --- |
| Название | Takt |
| Android `applicationId` | `ru.gadzhilaev.takt` |
| iOS Bundle ID | `ru.gadzhilaev.takt` |
| Версия | `mobile/pubspec.yaml` (`1.0.0+1` и далее) |
| API (release) | `https://taktapp.ru` (`AppConfig`) |
| Лицензия репо | [`LICENSE`](../LICENSE) — source-available, не OSS |

Тексты сторов: [`../mobile/store/metadata.md`](../mobile/store/metadata.md).  
Firebase / виджеты / deep links: [`../mobile/docs/MOBILE_SETUP.md`](../mobile/docs/MOBILE_SETUP.md).

## Удаление аккаунта

- Профиль web/mobile → «Удалить аккаунт»
- Web (требования Play): https://taktapp.ru/account-delete
- API: `DELETE /api/v1/users/me`
- Privacy: `/privacy`

## Подпись Android — Google Play и RuStore

**Не путать upload key и app signing key.**

| Ключ | Кто хранит | Зачем |
|------|------------|--------|
| **Upload key** | Вы (keystore `.jks`) | Подписываете AAB/APK перед загрузкой в консоль |
| **App signing key** | Google Play App Signing (у Google) | Итоговая подпись APK, который получают пользователи из Play |

**Рекомендация для совместимости обновлений:** один и тот же **upload keystore** для Google Play и RuStore (один `applicationId`).

1. Владелец создаёт keystore **локально** (агент не генерирует без разрешения):

```bash
keytool -genkey -v -keystore ~/Keys/takt-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias takt
```

2. Хранить `takt-upload.jks` и пароли **вне git** (password manager / encrypted backup).
3. `cp mobile/android/key.properties.example mobile/android/key.properties` → абсолютный путь к `.jks`.
4. **Google Play:** включить Play App Signing; в консоль загружать AAB, подписанный **upload**-ключом; Google переподписывает **app signing key**.
5. **RuStore:** загружать AAB/APK, подписанный **тем же upload keystore** (или тем ключом, который RuStore принимает как подпись приложения для этого `applicationId`). Иначе обновления между каналами могут конфликтовать.
6. Release без `key.properties` **падает** (не debug). Локальный smoke:  
   `ALLOW_DEBUG_RELEASE_SIGNING=true flutter build apk --release`
7. Сборка для сторов:  
   `flutter build appbundle --release` / `flutter build apk --release`
8. Firebase: `google-services.json` локально (gitignored). R8/minify включён в release.

## iOS (App Store)

1. Team / Bundle ID / Push (APNs) / Sign in with Apple в Xcode — без смены аккаунта агентом.
2. `GoogleService-Info.plist` локально (gitignored).
3. LaunchImage — фирменный `app_icon_1024` (не placeholder).
4. `PrivacyInfo.xcprivacy` в Runner.
5. `flutter build ipa --release` после codesign.
6. Privacy Nutrition Labels — только по факту из `/privacy` и `mobile/store/metadata.md`.

## Блокеры владельца

- Создать и сохранить upload keystore + `key.properties`
- Apple distribution cert / provisioning / TestFlight
- Скриншоты и карточки сторов
- Review/demo учётка из private (не в git)
- После rollout mobile Bearer WS: при возможности `ALLOW_WS_QUERY_TOKEN=false`
