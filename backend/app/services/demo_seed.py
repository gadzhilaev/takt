"""Idempotent demo seed for local/test only. Run via: python -m app.cli seed-demo"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.task import (
    ActivityLog,
    ChecklistItem,
    Comment,
    Task,
    TaskAssignee,
    TaskLabel,
    TaskPriority,
    Label,
)
from app.models.team import TaskStatus
from app.models.user import User, UserRole
from app.services.project_service import DEFAULT_STATUS_TEMPLATE

DEMO_MARKER = "[demo]"

DEMO_PROJECTS = [
    {
        "key": "mobile",
        "name": "Мобильное приложение",
        "description": "iOS/Android клиент трекера",
        "color": "#0ea5e9",
        "icon": "smartphone",
    },
    {
        "key": "api",
        "name": "Backend API",
        "description": "Сервис задач, auth и отчётов",
        "color": "#8b5cf6",
        "icon": "server",
    },
    {
        "key": "web",
        "name": "Разработка сайта",
        "description": "Маркетинговый сайт и лендинг",
        "color": "#22c55e",
        "icon": "globe",
    },
]


async def _user(db: AsyncSession, email: str, name: str, role: UserRole, password: str) -> User:
    existing = await db.scalar(select(User).where(User.email == email))
    if existing:
        return existing
    user = User(
        email=email,
        name=name,
        role=role,
        password_hash=hash_password(password),
        is_active=True,
        must_change_password=False,
    )
    db.add(user)
    await db.flush()
    return user


async def _ensure_project(db: AsyncSession, meta: dict, members: list[User]) -> Project:
    result = await db.execute(
        select(Project).where(Project.name == meta["name"], Project.description.ilike(f"%{DEMO_MARKER}%"))
    )
    project = result.scalar_one_or_none()
    if not project:
        # also match by exact name if already demo-created without marker in desc
        result = await db.execute(select(Project).where(Project.name == meta["name"], Project.is_default.is_(False)))
        project = result.scalar_one_or_none()
    if project:
        project.is_demo = True
        return project
    project = Project(
        name=meta["name"],
        description=f"{meta['description']} {DEMO_MARKER}",
        color=meta["color"],
        icon=meta["icon"],
        is_default=False,
        is_archived=False,
        is_demo=True,
    )
    db.add(project)
    await db.flush()
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
    demo_members = [u for u in members if u.role != UserRole.admin]
    for i, u in enumerate(demo_members):
        # First demo member becomes project admin; never auto-attach system admin.
        role = ProjectMemberRole.admin if i == 0 else ProjectMemberRole.member
        db.add(ProjectMember(project_id=project.id, user_id=u.id, role=role))
    await db.flush()
    return project


async def _statuses(db: AsyncSession, project_id: uuid.UUID) -> dict[str, TaskStatus]:
    rows = (
        await db.execute(
            select(TaskStatus).where(TaskStatus.project_id == project_id).order_by(TaskStatus.position)
        )
    ).scalars().all()
    return {s.name: s for s in rows}


async def _task_exists(db: AsyncSession, project_id: uuid.UUID, title: str) -> bool:
    return bool(
        await db.scalar(
            select(Task.id).where(
                Task.project_id == project_id,
                Task.title == title,
                Task.deleted_at.is_(None),
            )
        )
    )


async def _create_task(
    db: AsyncSession,
    *,
    project: Project,
    status: TaskStatus,
    title: str,
    author: User,
    priority: TaskPriority,
    due_offset_days: int | None,
    assignees: list[User],
    description: str,
    checklist: list[tuple[str, bool]] | None = None,
    comments: list[tuple[User, str]] | None = None,
    labels: list[str] | None = None,
) -> Task | None:
    if await _task_exists(db, project.id, title):
        return None
    now = datetime.now(UTC)
    task = Task(
        project_id=project.id,
        title=title,
        description=description,
        status_id=status.id,
        priority=priority,
        author_id=author.id,
        due_date=(now + timedelta(days=due_offset_days)) if due_offset_days is not None else None,
        position=await _next_pos(db, status.id),
        closed_at=now if status.is_done else None,
    )
    db.add(task)
    await db.flush()
    for u in assignees:
        db.add(TaskAssignee(task_id=task.id, user_id=u.id))
    for name in labels or []:
        label = await db.scalar(select(Label).where(Label.name == name))
        if not label:
            label = Label(name=name, color="#6366f1")
            db.add(label)
            await db.flush()
        db.add(TaskLabel(task_id=task.id, label_id=label.id))
    for i, (ctitle, done) in enumerate(checklist or []):
        db.add(ChecklistItem(task_id=task.id, title=ctitle, is_done=done, position=float(i + 1)))
    for author_c, body in comments or []:
        db.add(Comment(task_id=task.id, author_id=author_c.id, body=body))
    db.add(
        ActivityLog(
            task_id=task.id,
            user_id=author.id,
            action="created",
            created_at=now,
        )
    )
    return task


async def _next_pos(db: AsyncSession, status_id: uuid.UUID) -> float:
    from sqlalchemy import func

    max_pos = await db.scalar(
        select(func.max(Task.position)).where(Task.status_id == status_id, Task.deleted_at.is_(None))
    )
    return (max_pos or 0) + 1024.0


async def seed_demo_content(db: AsyncSession) -> dict:
    admin = await _user(db, "admin@example.com", "Администратор", UserRole.admin, "ChangeMeAdmin123!")
    member = await _user(db, "member@example.com", "Иван Участник", UserRole.member, "Member123!")
    designer = await _user(db, "demo.designer@example.com", "Анна Дизайн", UserRole.member, "Demo1234!")
    members = [admin, member, designer]

    created_projects = 0
    created_tasks = 0

    for meta in DEMO_PROJECTS:
        project = await _ensure_project(db, meta, members)
        # count if newly had no tasks
        before = await db.scalar(
            select(Task.id).where(Task.project_id == project.id).limit(1)
        )
        if before is None:
            created_projects += 1
        statuses = await _statuses(db, project.id)
        todo = statuses.get("К выполнению") or list(statuses.values())[0]
        doing = statuses.get("В работе") or todo
        review = statuses.get("На проверке") or doing
        done = statuses.get("Готово") or list(statuses.values())[-1]

        specs: list[dict] = []
        if meta["key"] == "mobile":
            specs = [
                dict(title="Онбординг экраны", status=todo, priority=TaskPriority.high, due=-2, assignees=[designer], desc="## Онбординг\nСверстать 3 экрана welcome.", checklist=[("Макет Figma", True), ("Верстка", False)], comments=[(member, "Нужен тёмный режим")], labels=["ui"]),
                dict(title="Push-уведомления", status=doing, priority=TaskPriority.urgent, due=1, assignees=[member], desc="Интеграция FCM/APNs.", checklist=[("Сертификаты", True), ("Клиент", False), ("Тесты", False)], comments=[(member, "Жду ключи")], labels=["mobile"]),
                dict(title="Офлайн-кэш задач", status=review, priority=TaskPriority.medium, due=3, assignees=[member], desc="Кэш списка при потере сети.", checklist=[], comments=[], labels=["mobile"]),
                dict(title="Авторизация по биометрии", status=done, priority=TaskPriority.medium, due=-10, assignees=[member, designer], desc="FaceID / Fingerprint.", checklist=[("iOS", True), ("Android", True)], comments=[(designer, "Принято")], labels=["security"]),
            ]
        elif meta["key"] == "api":
            specs = [
                dict(title="Пагинация задач", status=todo, priority=TaskPriority.medium, due=5, assignees=[member], desc="Cursor pagination для `/tasks`.", checklist=[("Спека", False)], comments=[], labels=["api"]),
                dict(title="RBAC проектов", status=doing, priority=TaskPriority.high, due=2, assignees=[member], desc="Права admin/member/viewer.", checklist=[("Модель", True), ("Тесты", False)], comments=[(member, "В работе")], labels=["security"]),
                dict(title="Экспорт Excel", status=review, priority=TaskPriority.low, due=0, assignees=[member], desc="Проверить кириллицу в filename.", checklist=[("Fix header", True)], comments=[], labels=["reports"]),
                dict(title="Bootstrap admin", status=done, priority=TaskPriority.low, due=-20, assignees=[member], desc="Создание первого админа.", checklist=[("CLI", True)], comments=[], labels=["infra"]),
                dict(title="Просроченный инцидент 500", status=todo, priority=TaskPriority.urgent, due=-1, assignees=[member, designer], desc="Разбор падения StatusOut.", checklist=[("Reproduce", True), ("Fix", False)], comments=[(member, "Правлю сериализацию")], labels=["bug"]),
            ]
        else:
            specs = [
                dict(title="Главный экран лендинга", status=todo, priority=TaskPriority.high, due=4, assignees=[designer], desc="Hero + CTA.", checklist=[("Копирайт", False), ("Макет", False)], comments=[], labels=["web"]),
                dict(title="Форма заявки", status=doing, priority=TaskPriority.medium, due=2, assignees=[member], desc="Валидация и отправка.", checklist=[("API", True), ("UI", False)], comments=[(designer, "Нужны состояния ошибок")], labels=["web"]),
                dict(title="SEO мета-теги", status=review, priority=TaskPriority.low, due=7, assignees=[member], desc="title/description/og.", checklist=[], comments=[], labels=["seo"]),
                dict(title="Деплой на Vercel", status=done, priority=TaskPriority.medium, due=-5, assignees=[member], desc="Прод preview.", checklist=[("DNS", True), ("CI", True)], comments=[(member, "Готово")], labels=["infra"]),
            ]

        for s in specs:
            t = await _create_task(
                db,
                project=project,
                status=s["status"],
                title=s["title"],
                author=member,
                priority=s["priority"],
                due_offset_days=s["due"],
                assignees=s["assignees"],
                description=s["desc"],
                checklist=s.get("checklist"),
                comments=s.get("comments"),
                labels=s.get("labels"),
            )
            if t:
                created_tasks += 1

    await db.commit()
    return {
        "projects": len(DEMO_PROJECTS),
        "created_projects_new": created_projects,
        "created_tasks": created_tasks,
        "users": ["admin@example.com", "member@example.com", "demo.designer@example.com"],
    }
