import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.task import Task
from app.models.team import TaskStatus
from app.models.user import User, UserRole
from app.services.bootstrap import DEFAULT_STATUSES

DEFAULT_STATUS_TEMPLATE = [
    ("К выполнению", "#3b82f6", 0, False),
    ("В работе", "#f59e0b", 1, False),
    ("На проверке", "#8b5cf6", 2, False),
    ("Готово", "#22c55e", 3, True),
]


async def get_project(db: AsyncSession, project_id: uuid.UUID) -> Project | None:
    q = (
        select(Project)
        .options(selectinload(Project.members))
        .where(Project.id == project_id)
    )
    return (await db.execute(q)).scalar_one_or_none()


async def list_projects_for_user(
    db: AsyncSession, user: User, *, include_archived: bool = False
) -> list[Project]:
    q = (
        select(Project)
        .join(ProjectMember, ProjectMember.project_id == Project.id)
        .where(ProjectMember.user_id == user.id)
        .options(selectinload(Project.members))
        .order_by(Project.is_default.desc(), Project.name.asc())
    )
    if not include_archived:
        q = q.where(Project.is_archived.is_(False))
    if user.role == UserRole.admin:
        q = select(Project).options(selectinload(Project.members)).order_by(
            Project.is_default.desc(), Project.name.asc()
        )
        if not include_archived:
            q = q.where(Project.is_archived.is_(False))
    return list((await db.execute(q)).scalars().unique().all())


async def user_project_role(
    db: AsyncSession, user: User, project_id: uuid.UUID
) -> ProjectMemberRole | None:
    if user.role == UserRole.admin:
        return ProjectMemberRole.admin
    row = await db.scalar(
        select(ProjectMember.role).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == user.id,
        )
    )
    return row


async def ensure_project_access(
    db: AsyncSession,
    user: User,
    project_id: uuid.UUID,
    *,
    min_role: ProjectMemberRole = ProjectMemberRole.viewer,
) -> ProjectMemberRole:
    role = await user_project_role(db, user, project_id)
    if role is None:
        raise PermissionError("no_access")
    order = {
        ProjectMemberRole.viewer: 0,
        ProjectMemberRole.member: 1,
        ProjectMemberRole.admin: 2,
    }
    if order[role] < order[min_role]:
        raise PermissionError("forbidden")
    return role


async def create_project(
    db: AsyncSession,
    *,
    name: str,
    description: str | None,
    color: str,
    icon: str,
    creator: User,
    member_ids: list[uuid.UUID] | None = None,
) -> Project:
    project = Project(
        name=name.strip(),
        description=description,
        color=color or "#4f46e5",
        icon=icon or "folder",
        is_default=False,
        is_archived=False,
    )
    db.add(project)
    await db.flush()
    for pos, (sname, scolor, p, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
        db.add(
            TaskStatus(
                project_id=project.id,
                name=sname,
                color=scolor,
                position=float(pos),
                is_done=is_done,
            )
        )
    db.add(
        ProjectMember(
            project_id=project.id,
            user_id=creator.id,
            role=ProjectMemberRole.admin,
        )
    )
    for uid in member_ids or []:
        if uid == creator.id:
            continue
        db.add(
            ProjectMember(
                project_id=project.id,
                user_id=uid,
                role=ProjectMemberRole.member,
            )
        )
    await db.flush()
    return await get_project(db, project.id)  # type: ignore[return-value]


async def project_progress(db: AsyncSession, project_id: uuid.UUID) -> dict:
    total = await db.scalar(
        select(func.count())
        .select_from(Task)
        .where(
            Task.project_id == project_id,
            Task.deleted_at.is_(None),
            Task.archived_at.is_(None),
            Task.parent_id.is_(None),
        )
    )
    done = await db.scalar(
        select(func.count())
        .select_from(Task)
        .join(TaskStatus, Task.status_id == TaskStatus.id)
        .where(
            Task.project_id == project_id,
            Task.deleted_at.is_(None),
            Task.archived_at.is_(None),
            Task.parent_id.is_(None),
            TaskStatus.is_done.is_(True),
        )
    )
    total_n = total or 0
    done_n = done or 0
    pct = round((done_n / total_n) * 100) if total_n else 0
    return {"total": total_n, "done": done_n, "percent": pct}


async def seed_statuses_for_legacy(db: AsyncSession) -> None:
    """Ensure DEFAULT_STATUSES import stays referenced for tests."""
    _ = DEFAULT_STATUSES
