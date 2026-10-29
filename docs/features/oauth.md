# OAuth

Провайдеры: **VK ID**, **Яндекс ID**, **Sign in with Apple**.

| Клиент | VK | Яндекс | Apple |
|--------|----|--------|-------|
| Web | да | да | нет (намеренно) |
| Mobile | да | да | да (при credentials + политике) |

- Первый вход может зарегистрировать пользователя (`login_or_register`)  
- Привязка/отвязка identities в профиле  
- Admin toggles: `platform_settings.oauth_login_methods`  
- Настройка секретов: [../OAUTH_SETUP.md](../OAUTH_SETUP.md)

**Planned / осторожно:** полноценный Sign in with Apple на production для RU-оператора — только после юр. clearance (149-ФЗ).
