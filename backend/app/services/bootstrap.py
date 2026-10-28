from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.security import hash_password
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


async def ensure_default_statuses(db: AsyncSession) -> None:
    count = await db.scalar(select(func.count()).select_from(TaskStatus))
    if count and count > 0:
        return
    for name, color, pos, is_done in DEFAULT_STATUSES:
        db.add(TaskStatus(name=name, color=color, position=float(pos), is_done=is_done))


async def ensure_admin_user(db: AsyncSession, settings: Settings) -> None:
    admin_count = await db.scalar(
        select(func.count()).select_from(User).where(User.role == UserRole.admin)
    )
    if admin_count and admin_count > 0:
        return
    existing = await db.scalar(select(User).where(User.email == settings.ADMIN_EMAIL.lower()))
    if existing:
        if existing.role != UserRole.admin:
            existing.role = UserRole.admin
        return
    db.add(
        User(
            email=settings.ADMIN_EMAIL.lower(),
            password_hash=hash_password(settings.ADMIN_PASSWORD),
            name=settings.ADMIN_NAME,
            role=UserRole.admin,
            is_active=True,
            must_change_password=False,
        )
    )


async def bootstrap_db(db: AsyncSession, settings: Settings) -> None:
    await ensure_team_settings(db)
    await ensure_default_statuses(db)
    await ensure_admin_user(db, settings)
    await db.commit()
