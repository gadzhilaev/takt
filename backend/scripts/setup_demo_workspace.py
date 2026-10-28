#!/usr/bin/env python3
"""Segregate demo / E2E data from the working workspace.

Creates «Демо пользователь» + demo project (credentials from env, never committed).
Moves confirmed technical tasks into the demo project or soft-deletes E2E noise.
Marks seed demo projects as is_demo and restricts membership to demo accounts.

Usage:
  DEMO_USER_EMAIL=demo@example.com DEMO_USER_PASSWORD='…' \\
    ./.venv/bin/python scripts/setup_demo_workspace.py

If DEMO_USER_PASSWORD is omitted, a random password is generated and written to
~/Documents/private/takt/correspondence/demo-credentials.md (outside git).
"""

from __future__ import annotations

import asyncio
import os
import re
import secrets
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.task import Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User, UserRole
from app.services.project_service import DEFAULT_STATUS_TEMPLATE

DEMO_USER_NAME = "Демо пользователь"
DEMO_PROJECT_NAME = "Демо-доска"
DEMO_PROJECT_DESC = "Изолированное демо-окружение Takt [demo-workspace]"
E2E_PROJECT_NAME = "[E2E] Playwright"
SEED_DEMO_NAMES = {"Backend API", "Мобильное приложение", "Разработка сайта"}
LEGACY_DEMO_EMAILS = {"demo.designer@example.com", "member@example.com"}

# Confirmed technical / E2E titles — safe to move or soft-delete.
CONFIRMED_TEST_TITLE = re.compile(
    r"^(E2E\b|Mobile\b|Mobile status\b|API move\b|DnD\b|assignee-fix\b|probe saved\b|"
    r"Audit test\b|Audit2\b|Browser smoke\b|Демо:)",
    re.IGNORECASE,
)

SAMPLE_TASKS = [
    ("Создать первую задачу", "Проверка создания", TaskPriority.medium, 0),
    ("Назначить исполнителя", "Проверка назначения", TaskPriority.high, 0),
    ("Переместить в работу", "Проверка DnD / столбцов", TaskPriority.medium, 1),
    ("Отправить на проверку", "Проверка статуса", TaskPriority.urgent, 2),
    ("Завершить задачу", "Перенос в «Готово»", TaskPriority.medium, 3),
]


def _private_credentials_path() -> Path:
    return Path.home() / "Documents" / "private" / "takt" / "correspondence" / "demo-credentials.md"


def _write_credentials(email: str, password: str, generated: bool) -> Path:
    path = _private_credentials_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"# Takt demo credentials\n\n"
        f"- Email: `{email}`\n"
        f"- Password: `{password}`\n"
        f"- Name: {DEMO_USER_NAME}\n"
        f"- Generated: {'yes' if generated else 'from env'}\n"
        f"- Updated: {datetime.now(UTC).isoformat()}\n\n"
        f"Не коммитить. Файл вне git-репозитория проекта.\n",
        encoding="utf-8",
    )
    return path


async def _ensure_demo_user(db, email: str, password: str) -> User:
    user = await db.scalar(select(User).where(User.email == email))
    if user:
        user.name = DEMO_USER_NAME
        user.password_hash = hash_password(password)
        user.is_active = True
        user.is_demo = True
        user.must_change_password = False
        user.role = UserRole.member
        return user
    user = User(
        email=email,
        name=DEMO_USER_NAME,
        role=UserRole.member,
        password_hash=hash_password(password),
        is_active=True,
        is_demo=True,
        must_change_password=False,
    )
    db.add(user)
    await db.flush()
    return user


async def _ensure_columns(db, project: Project) -> dict[int, TaskStatus]:
    existing = (
        await db.execute(
            select(TaskStatus).where(TaskStatus.project_id == project.id).order_by(TaskStatus.position)
        )
    ).scalars().all()
    if len(existing) >= 4 and any(s.is_done for s in existing):
        by_pos = {i: s for i, s in enumerate(existing)}
        return by_pos
    # Replace empty / legacy columns for the demo board only when empty of tasks.
    task_n = await db.scalar(
        select(func.count()).select_from(Task).where(Task.project_id == project.id, Task.deleted_at.is_(None))
    )
    if existing and (task_n or 0) == 0:
        for s in existing:
            await db.delete(s)
        await db.flush()
        existing = []
    if not existing:
        for pos, (sname, scolor, _p, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
            db.add(
                TaskStatus(
                    project_id=project.id,
                    name=sname,
                    color=scolor,
                    position=float(pos),
                    is_done=is_done,
                )
            )
        await db.flush()
        existing = (
            await db.execute(
                select(TaskStatus)
                .where(TaskStatus.project_id == project.id)
                .order_by(TaskStatus.position)
            )
        ).scalars().all()
    return {i: s for i, s in enumerate(existing)}


async def _ensure_membership(db, project_id, user_id, role=ProjectMemberRole.admin) -> None:
    row = await db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id, ProjectMember.user_id == user_id
        )
    )
    if row:
        row.role = role
        return
    db.add(ProjectMember(project_id=project_id, user_id=user_id, role=role))


async def _strip_non_demo_members(db, project: Project, keep_user_ids: set) -> None:
    members = (
        await db.execute(select(ProjectMember).where(ProjectMember.project_id == project.id))
    ).scalars().all()
    for m in members:
        if m.user_id not in keep_user_ids:
            await db.delete(m)


async def main() -> None:
    get_settings.cache_clear()
    email = (os.environ.get("DEMO_USER_EMAIL") or "demo@example.com").strip().lower()
    password = os.environ.get("DEMO_USER_PASSWORD")
    generated = False
    if not password:
        password = secrets.token_urlsafe(14)
        generated = True
    cred_path = _write_credentials(email, password, generated)

    report = {
        "moved_tasks": [],
        "soft_deleted_tasks": [],
        "demo_projects": [],
        "archived_projects": [],
        "left_in_obschee": [],
        "ambiguous": [],
        "demo_sample_tasks": [],
    }

    async with AsyncSessionLocal() as db:
        demo_user = await _ensure_demo_user(db, email, password)

        # Legacy fake demo accounts stay only as demo helpers.
        legacy_demo_users = (
            await db.execute(select(User).where(User.email.in_(LEGACY_DEMO_EMAILS)))
        ).scalars().all()
        keep_ids = {demo_user.id, *[u.id for u in legacy_demo_users]}

        demo_project = await db.scalar(
            select(Project).where(Project.name == DEMO_PROJECT_NAME, Project.is_demo.is_(True))
        )
        if not demo_project:
            demo_project = await db.scalar(select(Project).where(Project.name == DEMO_PROJECT_NAME))
        if not demo_project:
            demo_project = Project(
                name=DEMO_PROJECT_NAME,
                description=DEMO_PROJECT_DESC,
                color="#315F72",
                icon="sparkles",
                is_default=False,
                is_archived=False,
                is_demo=True,
            )
            db.add(demo_project)
            await db.flush()
        else:
            demo_project.is_demo = True
            demo_project.is_archived = False
            demo_project.description = DEMO_PROJECT_DESC

        await _ensure_membership(db, demo_project.id, demo_user.id, ProjectMemberRole.admin)
        for u in legacy_demo_users:
            await _ensure_membership(db, demo_project.id, u.id, ProjectMemberRole.member)
        await _strip_non_demo_members(db, demo_project, keep_ids)
        cols = await _ensure_columns(db, demo_project)
        report["demo_projects"].append(str(demo_project.id))

        # Sample demo tasks if board is empty of samples.
        existing_titles = {
            t
            for t in (
                await db.execute(
                    select(Task.title).where(
                        Task.project_id == demo_project.id, Task.deleted_at.is_(None)
                    )
                )
            ).scalars().all()
        }
        for title, desc, priority, col_idx in SAMPLE_TASKS:
            if title in existing_titles:
                continue
            status = cols.get(col_idx) or cols.get(0)
            if not status:
                continue
            task = Task(
                title=title,
                description=desc,
                status_id=status.id,
                project_id=demo_project.id,
                priority=priority,
                author_id=demo_user.id,
                position=float((col_idx + 1) * 1024),
            )
            db.add(task)
            await db.flush()
            if col_idx == 0:
                db.add(TaskAssignee(task_id=task.id, user_id=demo_user.id))
            report["demo_sample_tasks"].append(title)

        # Mark seed demo projects + restrict membership.
        for name in SEED_DEMO_NAMES:
            proj = await db.scalar(select(Project).where(Project.name == name))
            if not proj:
                continue
            proj.is_demo = True
            if not (proj.description or "").endswith("[demo-workspace]"):
                proj.description = ((proj.description or "") + " [demo-workspace]").strip()
            await _ensure_membership(db, proj.id, demo_user.id, ProjectMemberRole.admin)
            for u in legacy_demo_users:
                await _ensure_membership(db, proj.id, u.id, ProjectMemberRole.member)
            await _strip_non_demo_members(db, proj, keep_ids)
            report["demo_projects"].append(f"{name}:{proj.id}")

        # Archive E2E project (hide from UI).
        e2e = await db.scalar(select(Project).where(Project.name == E2E_PROJECT_NAME))
        if e2e:
            e2e.is_archived = True
            e2e.is_demo = True
            e2e.name = f"{E2E_PROJECT_NAME} (архив)"
            await _ensure_membership(db, e2e.id, demo_user.id, ProjectMemberRole.admin)
            await _strip_non_demo_members(db, e2e, {demo_user.id})
            report["archived_projects"].append(str(e2e.id))

        # Process tasks in «Общее» and other non-demo boards.
        obschee = await db.scalar(select(Project).where(Project.is_default.is_(True)))
        open_col = cols.get(0)
        all_tasks = (
            await db.execute(
                select(Task, Project)
                .join(Project, Project.id == Task.project_id)
                .where(Task.deleted_at.is_(None))
            )
        ).all()

        for task, project in all_tasks:
            title = task.title or ""
            confirmed = bool(CONFIRMED_TEST_TITLE.search(title))
            if project.is_demo and project.id != demo_project.id:
                continue  # leave seed-demo content in their demo projects
            if project.id == demo_project.id:
                continue
            if confirmed:
                # Soft-delete E2E noise rather than cluttering the demo board with dozens of clones.
                if re.match(r"^(E2E|Mobile|API move|DnD)\b", title, re.I):
                    task.deleted_at = datetime.now(UTC)
                    report["soft_deleted_tasks"].append(f"{task.id}\t{project.name}\t{title}")
                else:
                    # Meaningful demo leftovers (Демо:, Audit, smoke) → move into demo board.
                    if open_col:
                        task.project_id = demo_project.id
                        task.status_id = open_col.id
                        report["moved_tasks"].append(f"{task.id}\t{project.name}\t{title}")
                    else:
                        report["ambiguous"].append(f"{task.id}\t{project.name}\t{title}")
            elif project.id == (obschee.id if obschee else None):
                report["left_in_obschee"].append(f"{task.id}\t{title}")
            elif not project.is_demo:
                report["ambiguous"].append(f"{task.id}\t{project.name}\t{title}")

        # Remove all demo accounts from non-demo (working) projects.
        non_demo_projects = (
            await db.scalars(select(Project).where(Project.is_demo.is_(False)))
        ).all()
        strip_ids = keep_ids  # demo user + legacy seed demo accounts
        for proj in non_demo_projects:
            for uid in strip_ids:
                m = await db.scalar(
                    select(ProjectMember).where(
                        ProjectMember.project_id == proj.id, ProjectMember.user_id == uid
                    )
                )
                if m:
                    await db.delete(m)
                    report.setdefault("stripped_from_work", []).append(f"{proj.name}:{uid}")

        await db.commit()

    print("Demo workspace ready.")
    print(f"Credentials file: {cred_path}")
    print(f"Login: {email}")
    print(f"Demo project: {DEMO_PROJECT_NAME}")
    print(f"Moved: {len(report['moved_tasks'])}")
    print(f"Soft-deleted E2E: {len(report['soft_deleted_tasks'])}")
    print(f"Sample tasks added: {report['demo_sample_tasks']}")
    print(f"Archived: {report['archived_projects']}")
    print(f"Left in Общее (review): {len(report['left_in_obschee'])}")
    for line in report["left_in_obschee"][:30]:
        print(f"  KEEP? {line}")
    print(f"Ambiguous: {len(report['ambiguous'])}")
    for line in report["ambiguous"][:30]:
        print(f"  ? {line}")

    report_path = Path.home() / "Documents" / "private" / "takt" / "correspondence" / "demo-workspace-report.md"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        "# Demo workspace segregation report\n\n"
        + f"- Demo login: `{email}` (password in demo-credentials.md)\n"
        + f"- Moved ({len(report['moved_tasks'])}):\n"
        + "".join(f"  - {x}\n" for x in report["moved_tasks"])
        + f"- Soft-deleted ({len(report['soft_deleted_tasks'])}):\n"
        + "".join(f"  - {x}\n" for x in report["soft_deleted_tasks"][:80])
        + (f"  - … and {len(report['soft_deleted_tasks'])-80} more\n" if len(report["soft_deleted_tasks"]) > 80 else "")
        + f"- Left in Общее:\n"
        + "".join(f"  - {x}\n" for x in report["left_in_obschee"])
        + f"- Ambiguous:\n"
        + "".join(f"  - {x}\n" for x in report["ambiguous"])
        + f"- Demo projects: {report['demo_projects']}\n"
        + f"- Archived: {report['archived_projects']}\n",
        encoding="utf-8",
    )
    print(f"Full report: {report_path}")


if __name__ == "__main__":
    asyncio.run(main())
