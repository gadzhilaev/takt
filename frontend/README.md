# Takt — frontend

Next.js 14 (App Router) UI продукта **Takt**.

```bash
npm run dev      # http://localhost:3000
npm test         # vitest
npm run lint
npm run build
PW_CHANNEL=chrome npm run test:e2e
```

Прокси API в dev: `next.config.mjs` → backend (`BACKEND_INTERNAL_URL`, по умолчанию `http://127.0.0.1:8000`).

Документация репозитория: [`../docs/README.md`](../docs/README.md).
