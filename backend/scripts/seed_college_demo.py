#!/usr/bin/env python3
"""Seed «Колледж ДГУ» demo board (idempotent).

Requires DEMO_USER_EMAIL / DEMO_USER_PASSWORD already set up via setup_demo_workspace.py.

  cd backend && ./.venv/bin/python scripts/seed_college_demo.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.services.college_demo_seed import seed_college_demo


async def main() -> None:
    get_settings.cache_clear()
    settings = get_settings()
    async with AsyncSessionLocal() as db:
        report = await seed_college_demo(db, settings)
    print("College demo seed OK")
    print(f"  project_id: {report['project_id']}")
    print(f"  staff: {report['staff']}")
    print(f"  tasks_created: {report['tasks_created']}")
    print(f"  tasks_existing: {report['tasks_existing']}")
    print(f"  tech_cleaned: {report['tech_cleaned']}")
    print(f"  notifications: {report['notifications']}")


if __name__ == "__main__":
    asyncio.run(main())
