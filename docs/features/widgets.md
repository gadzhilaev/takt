# Home screen widgets

- Android: `TaktWidgetProvider`, конфиг per `appWidgetId`  
- iOS: WidgetKit `AppIntentConfiguration` (iOS 17+), Lock Screen accessories  
- App Group: `group.ru.gadzhilaev.takt`  
- Snapshot v3: задачи `mine` / `all` по проектам  
- **JWT в виджет не сохраняется**; после logout snapshot очищается  

Код: `mobile/lib/features/widget_sync/`, native targets в `mobile/ios`, `mobile/android`.
