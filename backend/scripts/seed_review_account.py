#!/usr/bin/env python3
"""Наполнить аккаунт для App Review правдоподобными данными (идемпотентно).

По умолчанию — DRY-RUN: печатает план и ничего не меняет. Выполнение — только с --apply.
Email и пароль — только из аргументов или ENV, в коде их нет:

  cd backend
  # 1) посмотреть план
  REVIEW_ACCOUNT_EMAIL=... ./.venv/bin/python scripts/seed_review_account.py
  # 2) выполнить
  REVIEW_ACCOUNT_EMAIL=... REVIEW_ACCOUNT_PASSWORD=... \\
    ./.venv/bin/python scripts/seed_review_account.py --apply

Если аккаунта нет — он создаётся (нужен пароль). Если есть — ревьюер выходит из проектов
вне набора сида (проекты без других реальных участников удаляются, права админа
передаются самому давнему реальному участнику), данные сида обновляются, сроки задач
пересчитываются от текущего момента. Пароль меняется, только если передан.

Защита:
  --force-foreign-projects  нужен, если аккаунт состоит в проектах с другими реальными
                            (не демо) участниками — иначе выполнение запрещено;
  --allow-production        нужен на ENV=production.
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
from app.services.review_account_seed import (
    REVIEW_PROJECTS,
    ReviewSeedRefused,
    plan_review_seed,
    seed_review_account,
)

_ACTION = {
    "delete": "проект будет удалён",
    "transfer": "права админа перейдут к {admin}, ревьюер выйдет",
    "leave": "ревьюер выйдет из проекта",
}


def _args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--email", default=os.environ.get("REVIEW_ACCOUNT_EMAIL"))
    p.add_argument("--password", default=os.environ.get("REVIEW_ACCOUNT_PASSWORD"))
    p.add_argument("--name", default=os.environ.get("REVIEW_ACCOUNT_NAME"))
    p.add_argument("--apply", action="store_true", help="выполнить (без флага — только план)")
    p.add_argument("--force-foreign-projects", action="store_true")
    p.add_argument("--allow-production", action="store_true")
    return p.parse_args()


def _print_plan(plan: dict) -> None:
    print("План:")
    if not plan["user_exists"]:
        print("  аккаунт не найден — будет создан (нужен пароль)")
    for p in plan["foreign"]:
        admin = (p.get("new_admin") or {}).get("name", "")
        print(f"  «{p['name']}»: {_ACTION[p['action']].format(admin=admin)}")
    if plan["user_exists"] and not plan["foreign"]:
        print("  посторонних проектов нет")
    names = ", ".join(f"«{p.name}»" for p in REVIEW_PROJECTS)
    print(f"  проекты сида (создать/обновить): {names}")
    if plan["shared_with_real"]:
        shared = ", ".join(f"«{n}»" for n in plan["shared_with_real"])
        print(f"  ВНИМАНИЕ: другие реальные участники в {shared}")
        print("  выполнение возможно только с --force-foreign-projects")


async def main() -> int:
    a = _args()
    if not a.email:
        print("Укажите --email или REVIEW_ACCOUNT_EMAIL", file=sys.stderr)
        return 2
    get_settings.cache_clear()
    settings = get_settings()
    if a.apply and settings.ENV.lower() in ("production", "prod") and not a.allow_production:
        print("ENV=production: добавьте --allow-production, если это осознанно.", file=sys.stderr)
        return 2

    async with AsyncSessionLocal() as db:
        plan = await plan_review_seed(db, email=a.email)
    _print_plan(plan)
    if plan.get("is_demo"):
        print("Аккаунт помечен как is_demo — для ревьюера нужен обычный аккаунт.", file=sys.stderr)
        return 2
    if not a.apply:
        print("\nDRY-RUN: ничего не изменено. Для выполнения добавьте --apply.")
        return 0
    if plan["shared_with_real"] and not a.force_foreign_projects:
        print(
            "\nОтказ: аккаунт состоит в проектах с другими реальными участниками. "
            "Похоже, это не аккаунт ревьюера. Если всё верно — добавьте --force-foreign-projects.",
            file=sys.stderr,
        )
        return 3

    try:
        async with AsyncSessionLocal() as db:
            report = await seed_review_account(
                db,
                email=a.email,
                password=a.password,
                name=a.name,
                force_foreign_projects=a.force_foreign_projects,
            )
    except ReviewSeedRefused as e:
        print(f"\nОтказ: {e}", file=sys.stderr)
        return 3
    print("\nReview account seed OK")
    print(f"  user_created: {report['user_created']}")
    for p in report["removed_projects"]:
        print(f"  removed from: {p['name']} ({p['action']})")
    for p in report["projects"]:
        print(f"  project: {p['name']} ({p['id']})")
    for key in ("tasks_created", "tasks_updated", "comments", "attachments", "notifications"):
        print(f"  {key}: {report[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
