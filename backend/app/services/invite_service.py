import secrets
import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invite import ProjectInvite, ProjectInviteStatus
from app.models.notification import Notification
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.user import User
from app.services import project_service


class InviteError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message


async def create_invite(
    db: AsyncSession,
    *,
    project: Project,
    email: str,
    invited_by: User,
) -> ProjectInvite:
    email_norm = email.strip().lower()
    if not email_norm:
        raise InviteError("invalid_email", "Укажите email")

    await project_service.ensure_project_access(
        db, invited_by, project.id, min_role=ProjectMemberRole.admin
    )

    existing_user = (
        await db.execute(select(User).where(User.email == email_norm))
    ).scalar_one_or_none()

    if existing_user:
        role = await project_service.user_project_role(db, existing_user, project.id)
        if role is not None:
            raise InviteError("already_member", "Пользователь уже в проекте")

    pending = await db.scalar(
        select(ProjectInvite).where(
            ProjectInvite.project_id == project.id,
            ProjectInvite.email == email_norm,
            ProjectInvite.status == ProjectInviteStatus.pending,
        )
    )
    if pending:
        raise InviteError("already_invited", "Приглашение уже отправлено")

    invite = ProjectInvite(
        project_id=project.id,
        email=email_norm,
        invited_by_id=invited_by.id,
        invitee_user_id=existing_user.id if existing_user else None,
        token=secrets.token_urlsafe(32),
        status=ProjectInviteStatus.pending,
        created_at=datetime.now(UTC),
    )
    db.add(invite)
    await db.flush()

    if existing_user:
        db.add(
            Notification(
                user_id=existing_user.id,
                actor_id=invited_by.id,
                project_id=project.id,
                kind="project_invite",
                title=f"Приглашение в «{project.name}»",
                body=f"{invited_by.name} приглашает вас в проект",
                is_read=False,
                created_at=datetime.now(UTC),
            )
        )
    return invite


async def cancel_invite(db: AsyncSession, invite: ProjectInvite, user: User) -> None:
    await project_service.ensure_project_access(
        db, user, invite.project_id, min_role=ProjectMemberRole.admin
    )
    if invite.status != ProjectInviteStatus.pending:
        raise InviteError("not_pending", "Приглашение уже обработано")
    invite.status = ProjectInviteStatus.cancelled
    invite.responded_at = datetime.now(UTC)


async def accept_invite(db: AsyncSession, invite: ProjectInvite, user: User) -> None:
    if invite.status != ProjectInviteStatus.pending:
        raise InviteError("not_pending", "Приглашение уже обработано")
    if invite.email.lower() != user.email.lower():
        raise InviteError("wrong_user", "Приглашение предназначено другому email")
    role = await project_service.user_project_role(db, user, invite.project_id)
    if role is None:
        db.add(
            ProjectMember(
                project_id=invite.project_id,
                user_id=user.id,
                role=ProjectMemberRole.member,
            )
        )
    invite.status = ProjectInviteStatus.accepted
    invite.invitee_user_id = user.id
    invite.responded_at = datetime.now(UTC)
    await db.flush()


async def decline_invite(db: AsyncSession, invite: ProjectInvite, user: User) -> None:
    if invite.status != ProjectInviteStatus.pending:
        raise InviteError("not_pending", "Приглашение уже обработано")
    if invite.email.lower() != user.email.lower():
        raise InviteError("wrong_user", "Приглашение предназначено другому email")
    invite.status = ProjectInviteStatus.declined
    invite.invitee_user_id = user.id
    invite.responded_at = datetime.now(UTC)


async def list_pending_for_user(db: AsyncSession, user: User) -> list[ProjectInvite]:
    rows = (
        await db.execute(
            select(ProjectInvite).where(
                ProjectInvite.email == user.email.lower(),
                ProjectInvite.status == ProjectInviteStatus.pending,
            )
        )
    ).scalars().all()
    return list(rows)


async def list_project_invites(db: AsyncSession, project_id: uuid.UUID) -> list[ProjectInvite]:
    rows = (
        await db.execute(
            select(ProjectInvite)
            .where(ProjectInvite.project_id == project_id)
            .order_by(ProjectInvite.created_at.desc())
        )
    ).scalars().all()
    return list(rows)


async def link_pending_invites_to_user(db: AsyncSession, user: User) -> None:
    await db.execute(
        update(ProjectInvite)
        .where(
            ProjectInvite.email == user.email.lower(),
            ProjectInvite.status == ProjectInviteStatus.pending,
            ProjectInvite.invitee_user_id.is_(None),
        )
        .values(invitee_user_id=user.id)
    )
