import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.security import hash_password
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.team import TaskStatus, TeamSettings
from app.models.user import User, UserRole

DEFAULT_STATUSES = [
    ("Бэклог", "#94a3b8", 0, False),
    ("К выполнению", "#3b82f6", 1, False),
    ("В работе", "#f59e0b", 2, False),
    ("На проверке", "#8b5cf6", 3, False),
    ("Готово", "#22c55e", 4, True),
]


async def ensure_team_settings(db: AsyncSession) -> None:
    result = await db.execute(select(TeamSettings).where(TeamSettings.id == 1))
    if not result.scalar_one_or_none():
        db.add(TeamSettings(id=1, team_name="Моя команда"))


async def ensure_default_project(db: AsyncSession) -> Project:
    result = await db.execute(select(Project).where(Project.is_default.is_(True)))
    project = result.scalar_one_or_none()
    if project:
        return project
    project = Project(
        id=uuid.uuid4(),
        name="Общее",
        description="Задачи без отдельного проекта",
        color="#4f46e5",
        icon="inbox",
        is_default=True,
        is_archived=False,
    )
    db.add(project)
    await db.flush()
    return project


async def ensure_default_statuses(db: AsyncSession, project: Project) -> None:
    count = await db.scalar(
        select(func.count()).select_from(TaskStatus).where(TaskStatus.project_id == project.id)
    )
    if count and count > 0:
        # Backfill orphan statuses
        orphans = (
            await db.execute(select(TaskStatus).where(TaskStatus.project_id.is_(None)))
        ).scalars().all()
        for s in orphans:
            s.project_id = project.id
        return
    # Migrate legacy global statuses if any
    legacy = (await db.execute(select(TaskStatus).where(TaskStatus.project_id.is_(None)))).scalars().all()
    if legacy:
        for s in legacy:
            s.project_id = project.id
        return
    for name, color, pos, is_done in DEFAULT_STATUSES:
        db.add(
            TaskStatus(
                name=name,
                color=color,
                position=float(pos),
                is_done=is_done,
                project_id=project.id,
            )
        )


async def ensure_admin_user(db: AsyncSession, settings: Settings) -> User | None:
    admin_count = await db.scalar(
        select(func.count()).select_from(User).where(User.role == UserRole.admin)
    )
    if admin_count and admin_count > 0:
        result = await db.execute(select(User).where(User.role == UserRole.admin).limit(1))
        return result.scalar_one_or_none()
    existing = await db.scalar(select(User).where(User.email == settings.ADMIN_EMAIL.lower()))
    if existing:
        if existing.role != UserRole.admin:
            existing.role = UserRole.admin
        return existing
    user = User(
        email=settings.ADMIN_EMAIL.lower(),
        password_hash=hash_password(settings.ADMIN_PASSWORD),
        name=settings.ADMIN_NAME,
        role=UserRole.admin,
        is_active=True,
        must_change_password=False,
    )
    db.add(user)
    await db.flush()
    return user


async def ensure_project_memberships(db: AsyncSession, project: Project) -> None:
    users = (await db.execute(select(User))).scalars().all()
    for user in users:
        exists = await db.scalar(
            select(ProjectMember.id).where(
                ProjectMember.project_id == project.id,
                ProjectMember.user_id == user.id,
            )
        )
        if exists:
            continue
        role = ProjectMemberRole.admin if user.role == UserRole.admin else ProjectMemberRole.member
        db.add(ProjectMember(project_id=project.id, user_id=user.id, role=role))


async def bootstrap_db(db: AsyncSession, settings: Settings) -> None:
    await ensure_team_settings(db)
    project = await ensure_default_project(db)
    await ensure_default_statuses(db, project)
    await ensure_admin_user(db, settings)
    await ensure_project_memberships(db, project)
    # Backfill tasks without project
    from app.models.task import Task

    await db.execute(
        Task.__table__.update()
        .where(Task.project_id.is_(None))
        .values(project_id=project.id)
    )
    await db.commit()
