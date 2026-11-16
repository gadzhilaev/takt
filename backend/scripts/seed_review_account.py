#!/usr/bin/env python3
"""Наполнить аккаунт для App Review правдоподобными данными (идемпотентно).

Email и пароль — только из аргументов или ENV, в коде их нет:

  cd backend
  REVIEW_ACCOUNT_EMAIL=... REVIEW_ACCOUNT_PASSWORD=... \\
    ./.venv/bin/python scripts/seed_review_account.py

  # или
  ./.venv/bin/python scripts/seed_review_account.py --email ... --password ...

Если аккаунта нет — он создаётся (нужен пароль). Если есть — данные обновляются,
сроки задач пересчитываются от текущего момента. Пароль меняется, только если передан.
На ENV=production скрипт требует явный флаг --allow-production.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.services.review_account_seed import seed_review_account


def _args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--email", default=os.environ.get("REVIEW_ACCOUNT_EMAIL"))
    p.add_argument("--password", default=os.environ.get("REVIEW_ACCOUNT_PASSWORD"))
    p.add_argument("--name", default=os.environ.get("REVIEW_ACCOUNT_NAME"))
    p.add_argument("--allow-production", action="store_true")
    return p.parse_args()


async def main() -> int:
    a = _args()
    if not a.email:
        print("Укажите --email или REVIEW_ACCOUNT_EMAIL", file=sys.stderr)
        return 2
    get_settings.cache_clear()
    settings = get_settings()
    if settings.ENV.lower() in ("production", "prod") and not a.allow_production:
        print("ENV=production: добавьте --allow-production, если это осознанно.", file=sys.stderr)
        return 2
    async with AsyncSessionLocal() as db:
        report = await seed_review_account(db, email=a.email, password=a.password, name=a.name)
    print("Review account seed OK")
    print(f"  user_created: {report['user_created']}")
    for p in report["projects"]:
        print(f"  project: {p['name']} ({p['id']})")
    for key in ("tasks_created", "tasks_updated", "comments", "attachments", "notifications"):
        print(f"  {key}: {report[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
