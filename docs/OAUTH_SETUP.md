# OAuth: Apple, VK ID, Яндекс ID

Backend FastAPI — единый центр. Client secrets и Apple private key **только** на сервере.

Пока credentials не заданы и реальный вход не проверен, OAuth **не считается production-ready**.

## Политика РФ (149-ФЗ)

Изучите актуальную редакцию **ч. 10 ст. 8 Федерального закона №149-ФЗ**.

- Не считайте Apple ID автоматически допустимым для аудитории РФ, если закон применим к оператору Takt.
- Настройки по умолчанию: `OAUTH_APPLE_ENABLED=false`, `OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR=false`.
- При `OAUTH_OPERATOR_REGION=ru` Apple остаётся выключенным, даже если credentials заданы, пока явно не разрешите `OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR=true` после юридического решения.
- Геолокация пользователя по IP **не** используется как критерий.
- Email/password не отключается этими настройками.

## Общие redirect URI

Добавьте в allowlist (`OAUTH_ALLOWED_REDIRECT_URIS`):

- Web: `https://taktapp.ru/api/v1/auth/oauth/callback` (и localhost для dev)
- Mobile deep link: `takt://oauth/callback`

## Apple

1. [Apple Developer](https://developer.apple.com) → Certificates, Identifiers & Profiles.
2. Создайте **App ID** (iOS/Android bundle) с Sign In with Apple.
3. Создайте **Services ID** (web client id) → `OAUTH_APPLE_CLIENT_ID`.
4. Configure domains + return URL = web callback выше.
5. Keys → Sign in with Apple → скачайте `.p8` → `OAUTH_APPLE_PRIVATE_KEY_FILE` или PEM в `OAUTH_APPLE_PRIVATE_KEY`.
6. Заполните `OAUTH_APPLE_TEAM_ID`, `OAUTH_APPLE_KEY_ID`.
7. Включите `OAUTH_APPLE_ENABLED=true` только после юр. решения для целевой аудитории.

Native iOS: передайте `id_token` на `POST /api/v1/auth/oauth/mobile` (Sign in with Apple SDK). Не кладите private key в приложение.

## VK ID

1. [VK ID / кабинет приложений](https://id.vk.com/) — создайте приложение.
2. `OAUTH_VK_CLIENT_ID`, `OAUTH_VK_CLIENT_SECRET`.
3. Redirect URI из allowlist.
4. `OAUTH_VK_ENABLED=true`.
5. В кабинете VK ID: **Доступы → Почта** и **Авторизация → Фото профиля** — включить (имя/фамилия обычно уже в личных данных). Фото скачивается на сервер и становится аватаркой Takt, если своей ещё нет.

Используйте актуальный OAuth 2.1 / PKCE поток VK ID (не устаревший standalone).

## Яндекс ID

1. [OAuth Яндекса](https://oauth.yandex.ru/) — зарегистрируйте приложение.
2. `OAUTH_YANDEX_CLIENT_ID`, `OAUTH_YANDEX_CLIENT_SECRET`.
3. Callback URL из allowlist.
4. `OAUTH_YANDEX_ENABLED=true`.

## Админка: вкл/выкл способов входа

`/admin/settings` → блок «Способы входа» пишет `platform_settings.oauth_login_methods`
(`apple` / `vk` / `yandex` / `email_password`). Выключение скрывает кнопки на web и в Flutter;
credentials в `.env` не трогаются. Без записи в БД все способы по умолчанию включены (если credentials есть).

## Привязка / отвязка

- Привязка: авторизованный пользователь → `/auth/oauth/{provider}/start?link=true`.
- Автослияние **только по email запрещено** — при занятом email нужен вход в существующий аккаунт и явная привязка.
- Нельзя отвязать последний способ входа без пароля.

## CLI super admin

```bash
cd backend
./.venv/bin/python -m app.cli grant-super-admin --email you@example.com
```

Не выдавайте platform role по email-домену или OAuth-провайдеру.
