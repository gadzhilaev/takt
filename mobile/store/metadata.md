# Takt — store metadata (компактно)

Основано на фактическом поведении приложения и https://taktapp.ru/privacy.  
Пароли demo / review — только private credentials, **не** в git.

## Идентификаторы

| | |
| --- | --- |
| Название | Takt |
| Android `applicationId` | `ru.gadzhilaev.takt` |
| iOS Bundle ID | `ru.gadzhilaev.takt` |
| Версия | `1.0.0` + build `1` (`pubspec.yaml`) |
| Категория | Productivity / Производительность |
| Возраст | 4+ / Everyone |
| Иконка | `mobile/assets/brand/app_icon_1024.png` |
| Support | support@taktapp.ru |
| Privacy | https://taktapp.ru/privacy |
| Account delete | in-app + https://taktapp.ru/account-delete |

## App Store

**Subtitle (≤30):** Kanban для команд  
**Keywords:** kanban,задачи,проекты,доска,команда,productivity,task,board  
**Description:**  
Takt — простой менеджер проектов вокруг Kanban. Регистрация по email (OTP), вход, OAuth (VK, Яндекс, Sign in with Apple на iOS), проекты и приглашения, доска со столбцами, задачи с исполнителями (≥1) и срочностью, комментарии, чеклист, in-app и push-уведомления, виджеты домашнего экрана. Без рекламных дашбордов.

**Review notes (шаблон):**  
- Учётка для проверки: предоставить отдельно (не публиковать пароль).  
- Основные сценарии: login → проект → доска → задача → профиль → удаление аккаунта.  
- OAuth: VK / Яндекс; Apple Sign In на iOS.  
- Удаление аккаунта: Профиль → «Удалить аккаунт».  
- Нет IDFA / рекламного трекинга → ATT не нужен.

## Google Play

**Short (≤80):** Простой Kanban: проекты, доска, задачи и push.  
**Full:** тот же смысл, что App Store description + ссылка на удаление аккаунта `/account-delete`.  
**Feature graphic / screenshots:** из `docs/screenshots/readme/` + свежие device captures (чеклист ниже).  
**Contact:** support@taktapp.ru  

## RuStore

Те же тексты (RU). Категория: «Производительность».  
Тот же `applicationId` и **тот же upload keystore**, что для Play (см. `docs/release.md`).  
Проверить сборку на устройстве без Google Play Services (OAuth HTTPS + FCM).

## Скриншоты (чеклист)

1. Вход / регистрация  
2. Список проектов  
3. Kanban (светлая)  
4. Карточка задачи  
5. Уведомления / профиль  
6. (опц.) виджет  

## Privacy questionnaire / Data safety — checklist по факту

Отвечать только «да», если реально собирается (см. `/privacy`):

| Данные | Собираем? | Цель | Передача третьим | Обязательно |
| --- | --- | --- | --- | --- |
| Имя, email | Да | аккаунт / вход | нет (кроме OAuth-провайдера при входе) | для сервиса |
| Пароль / OAuth id | Да (хеш / provider id) | аутентификация | провайдер OAuth при входе | да |
| Аватар | Опционально | профиль | нет | нет |
| Контент проектов/задач | Да | работа доски | нет | для сервиса |
| Push token (FCM/APNs) | Если разрешил | уведомления | Firebase/Apple инфраструктура push | нет |
| IP / user-agent / логи | Технические | безопасность / стабильность | хостинг | служебные |
| Рекламный ID / трекинг | **Нет** | — | — | — |
| Продажа данных | **Нет** | — | — | — |

Удаление: in-app + web; сессии/push отзываются; общие проекты команды сохраняются; sole-admin с участниками → нужно назначить другого admin (API 409).

Не заполнять анкеты наугад. Если пункт неясен — уточнить у владельца / по коду.

## Review account

- Отдельный demo/staging пользователь (`DEMO_USER_*` / private file).  
- Не коммитить пароль.  
- Не давать доступ к production-рабочим пространствам сотрудников.
