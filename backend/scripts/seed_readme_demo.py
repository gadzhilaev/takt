#!/usr/bin/env python3
"""Seed product-style demo board for README screenshots.

  cd backend && ./.venv/bin/python scripts/seed_readme_demo.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.services.readme_demo_seed import seed_readme_demo


async def main() -> None:
    settings = get_settings()
    async with AsyncSessionLocal() as db:
        report = await seed_readme_demo(db, settings)
    print("README demo seed OK")
    for k, v in report.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    asyncio.run(main())
