# Takt Lucide icons

Единый каталог интерфейсных SVG на базе [Lucide](https://lucide.dev/icons/).

- `viewBox` 24×24, `stroke-width` **1.75**, `stroke-linecap/linejoin` round
- Имена семантические (`home.svg`, `notifications.svg`) — см. `manifest.json`
- Брендовые логотипы **не** здесь: `mobile/assets/brand/`

## Подключение без дублирования

- Flutter: `mobile/assets/icons` → symlink на `../../shared/icons`
- Web: `AppIcon` через `lucide-react` с той же картой имён (штрихи 1.75)

Пересинхронизация из `lucide-static`:

```bash
node scripts/sync-lucide-icons.mjs
```
