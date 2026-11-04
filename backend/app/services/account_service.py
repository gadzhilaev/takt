"""Self-service account deletion (App Store / Play / RuStore compliance).

Strategy: anonymize the user row (keep FK integrity for shared content) after
leaving projects. Sole-member projects are hard-deleted so empty workspaces
do not linger. Sole admins of shared projects must promote another admin first.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth import RefreshToken
from app.models.device_push_token import DevicePushToken
from app.models.invite import ProjectInvite, ProjectInviteStatus
from app.models.notification import Notification
from app.models.platform import UserIdentity
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.push_subscription import PushSubscription
from app.models.task import TaskAssignee
from app.models.user import PlatformRole, User
from app.services.auth_service import revoke_all_user_tokens


class AccountError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = 400,
        *,
        projects: list[dict] | None = None,
    ):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.projects = projects or []


async def delete_own_account(db: AsyncSession, user: User) -> None:
    if getattr(user, "is_demo", False):
        raise AccountError(
            "demo_account",
            "Демо-аккаунт нельзя удалить",
            403,
        )

    if user.platform_role == PlatformRole.super_admin:
        others = await db.scalar(
            select(func.count())
            .select_from(User)
            .where(
                User.platform_role == PlatformRole.super_admin,
                User.id != user.id,
                User.is_active.is_(True),
            )
        )
        if not others:
            raise AccountError(
                "last_super_admin",
                "Нельзя удалить последнего суперадмина платформы. "
                "Сначала назначьте другого суперадмина.",
                409,
            )

    memberships = (
        await db.execute(select(ProjectMember).where(ProjectMember.user_id == user.id))
    ).scalars().all()

    blocked: list[dict] = []
    sole_project_ids: list[uuid.UUID] = []
    leave_project_ids: list[uuid.UUID] = []

    for membership in memberships:
        member_count = await db.scalar(
            select(func.count())
            .select_from(ProjectMember)
            .where(ProjectMember.project_id == membership.project_id)
        ) or 0
        if member_count <= 1:
            sole_project_ids.append(membership.project_id)
            continue

        if membership.role == ProjectMemberRole.admin:
            other_admins = await db.scalar(
                select(func.count())
                .select_from(ProjectMember)
                .where(
                    ProjectMember.project_id == membership.project_id,
                    ProjectMember.role == ProjectMemberRole.admin,
                    ProjectMember.user_id != user.id,
                )
            ) or 0
            if other_admins == 0:
                project = await db.get(Project, membership.project_id)
                blocked.append(
                    {
                        "id": str(membership.project_id),
                        "name": project.name if project else "Проект",
                    }
                )
                continue

        leave_project_ids.append(membership.project_id)

    if blocked:
        names = ", ".join(p["name"] for p in blocked)
        raise AccountError(
            "sole_admin",
            f"Сначала назначьте другого администратора в проектах: {names}",
            409,
            projects=blocked,
        )

    # Hard-delete projects where the user is the only member.
    for project_id in sole_project_ids:
        await db.execute(delete(Project).where(Project.id == project_id))

    # Leave shared projects without destroying teammates' data.
    if leave_project_ids:
        await db.execute(
            delete(ProjectMember).where(
                ProjectMember.user_id == user.id,
                ProjectMember.project_id.in_(leave_project_ids),
            )
        )
        await db.execute(
            delete(TaskAssignee).where(
                TaskAssignee.user_id == user.id,
            )
        )
    else:
        await db.execute(delete(TaskAssignee).where(TaskAssignee.user_id == user.id))

    # Cancel pending invites created by this user; drop memberships leftovers.
    await db.execute(
        update(ProjectInvite)
        .where(
            ProjectInvite.invited_by_id == user.id,
            ProjectInvite.status == ProjectInviteStatus.pending,
        )
        .values(status=ProjectInviteStatus.cancelled)
    )
    await db.execute(delete(ProjectMember).where(ProjectMember.user_id == user.id))

    await revoke_all_user_tokens(db, user.id)
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == user.id))
    await db.execute(delete(DevicePushToken).where(DevicePushToken.user_id == user.id))
    await db.execute(delete(PushSubscription).where(PushSubscription.user_id == user.id))
    await db.execute(delete(Notification).where(Notification.user_id == user.id))
    await db.execute(delete(UserIdentity).where(UserIdentity.user_id == user.id))

    if user.avatar_path:
        Path(user.avatar_path).unlink(missing_ok=True)

    # Anonymize — keep row so authored tasks/comments in shared projects stay valid.
    tombstone = uuid.uuid4().hex
    user.email = f"deleted-{tombstone}@deleted.takt.local"
    user.name = "Удалённый аккаунт"
    user.password_hash = None
    user.avatar_path = None
    user.is_active = False
    user.must_change_password = False
    user.platform_role = PlatformRole.none
    user.blocked_until = None
    user.block_reason = "account_deleted"
    user.last_login_at = None

    await db.flush()
