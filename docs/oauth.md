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

Добавьте в allowlist (`OAUTH_ALLOWED_REDIRECT_URIS`) и в кабинеты VK / Яндекс:

- Web + Mobile (authorize): `https://taktapp.ru/api/v1/auth/oauth/callback` (и localhost для dev)

Mobile VK / Яндекс: authorize открывается через `GET /oauth/launch?url=…` (302 на провайдера,
чтобы DNS шёл с нашего домена), callback — **тот же HTTPS**, что в кабинетах. ASWebAuthenticationSession
ловит `https://…/oauth/callback` (или bounce на `takt://oauth/callback`). Затем `POST /oauth/mobile`.
Custom-scheme в кабинетах провайдеров **не** регистрируем.

## Apple (только mobile; на сайте кнопок нет)

Bundle ID приложения: `ru.gadzhilaev.takt`.

1. [Apple Developer](https://developer.apple.com) → **Certificates, Identifiers & Profiles**.
2. **Identifiers → App IDs** → ваш App ID `ru.gadzhilaev.takt` → включите capability **Sign In with Apple** → Save.
3. **Keys → +** → **Sign in with Apple** → Configure (выберите App ID) → Continue → Register → **скачайте `.p8` один раз**.
4. Запишите:
   - **Key ID** → `OAUTH_APPLE_KEY_ID`
   - **Team ID** (Membership) → `OAUTH_APPLE_TEAM_ID`
   - Client ID для native = bundle id → `OAUTH_APPLE_CLIENT_ID=ru.gadzhilaev.takt`
5. На сервере положите ключ, например `/opt/takt/secrets/AuthKey_XXXXX.p8`, и в `/opt/takt/.env`:
   ```bash
   OAUTH_APPLE_ENABLED=true
   OAUTH_APPLE_CLIENT_ID=ru.gadzhilaev.takt
   OAUTH_APPLE_TEAM_ID=…
   OAUTH_APPLE_KEY_ID=…
   OAUTH_APPLE_PRIVATE_KEY_FILE=/secrets/AuthKey_XXXXX.p8
   # для оператора РФ после юр. решения:
   OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR=true
   ```
6. Рестарт backend. В админке `/admin/settings` включите **Apple**.
7. В приложении кнопка появится после `enabled` у `/api/v1/auth/oauth/providers`.
8. Mobile: **Apple** — нативный Sign in with Apple (системный sheet, не Safari) → `id_token` на `POST /api/v1/auth/oauth/mobile`. **VK / Яндекс** — `ASWebAuthenticationSession` (`flutter_web_auth_2`): authorize с HTTPS callback → bounce на `takt://oauth/callback` → `POST /mobile` с `code` + `state` (PKCE verifier на сервере). Private key **только** на сервере.

Пока `OAUTH_OPERATOR_REGION=ru` и `OAUTH_APPLE_ALLOWED_FOR_RU_OPERATOR=false`, Apple останется выключенным политикой (149-ФЗ).

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
