#!/usr/bin/env python3
"""List likely E2E / test tasks for manual review. Does NOT delete anything.

Usage (from backend/ with venv):
  ./.venv/bin/python scripts/list_test_tasks.py

After you confirm, soft-delete with:
  ./.venv/bin/python scripts/list_test_tasks.py --delete-ids <uuid> <uuid>
"""

from __future__ import annotations

import argparse
import asyncio
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models.project import Project
from app.models.task import Task

TEST_TITLE = re.compile(
    r"^(E2E\b|Mobile\b|API move\b|DnD\b|\[E2E\])",
    re.IGNORECASE,
)
E2E_PROJECT = "[E2E] Playwright"


async def main(delete_ids: list[str]) -> None:
    get_settings.cache_clear()
    async with AsyncSessionLocal() as db:
        if delete_ids:
            for raw in delete_ids:
                task = await db.get(Task, raw)
                if not task or task.deleted_at is not None:
                    print(f"skip {raw}")
                    continue
                from datetime import UTC, datetime

                task.deleted_at = datetime.now(UTC)
                print(f"soft-deleted {raw} «{task.title}»")
            await db.commit()
            return

        q = (
            select(Task, Project.name)
            .outerjoin(Project, Project.id == Task.project_id)
            .where(Task.deleted_at.is_(None))
            .order_by(Task.created_at.desc())
            .limit(500)
        )
        rows = (await db.execute(q)).all()
        print("Candidates (title match or E2E project). Nothing deleted.\n")
        for task, pname in rows:
            if pname == E2E_PROJECT or TEST_TITLE.search(task.title or ""):
                print(f"{task.id}\t{pname or '-'}\t{task.title}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--delete-ids", nargs="*", default=[])
    args = parser.parse_args()
    asyncio.run(main(args.delete_ids))
