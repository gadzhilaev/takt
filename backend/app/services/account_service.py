"""Self-service account deletion (App Store / Play / RuStore compliance).

Strategy: anonymize the user row (keep FK integrity for shared content) after
leaving projects. Deletion is never blocked by project ownership
(App Store Guideline 5.1.1(v)):

- the only member → project is hard-deleted;
- the only admin with real (non-demo) teammates → admin rights go to the
  earliest-joined real member, who gets an in-app notification;
- the only admin with demo-only teammates → project is hard-deleted;
- otherwise → the user just leaves the project.

``plan_account_deletion`` returns the same plan for the confirmation UI.
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
from app.services.attachment_service import project_attachment_dirs, remove_dirs
from app.services.auth_service import revoke_all_user_tokens
from app.services.notify_service import create_in_app

ACTION_DELETE = "delete"
ACTION_TRANSFER = "transfer"
ACTION_LEAVE = "leave"


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


def _ensure_deletable(user: User) -> None:
    if getattr(user, "is_demo", False):
        raise AccountError(
            "demo_account",
            "Демо-аккаунт нельзя удалить",
            403,
        )


async def _ensure_not_last_super_admin(db: AsyncSession, user: User) -> None:
    if user.platform_role != PlatformRole.super_admin:
        return
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


async def plan_project_exits(db: AsyncSession, user: User) -> list[dict]:
    """What happens to each project of ``user`` on account deletion."""
    memberships = (
        await db.execute(
            select(ProjectMember, Project)
            .join(Project, Project.id == ProjectMember.project_id)
            .where(ProjectMember.user_id == user.id)
            .order_by(Project.name)
        )
    ).all()

    plans: list[dict] = []
    for membership, project in memberships:
        others = (
            await db.execute(
                select(ProjectMember, User)
                .join(User, User.id == ProjectMember.user_id)
                .where(
                    ProjectMember.project_id == project.id,
                    ProjectMember.user_id != user.id,
                )
                # Earliest-joined first; active accounts before deactivated ones.
                .order_by(User.is_active.desc(), ProjectMember.created_at, ProjectMember.id)
            )
        ).all()
        plan: dict = {
            "id": str(project.id),
            "name": project.name,
            "action": ACTION_LEAVE,
            "new_admin": None,
        }
        if project.is_default:
            pass  # общий проект «Общее» никогда не удаляется — только выход
        elif not others:
            plan["action"] = ACTION_DELETE
            plan["reason"] = "only_member"
        elif membership.role == ProjectMemberRole.admin and not any(
            m.role == ProjectMemberRole.admin for m, _u in others
        ):
            real = [(m, u) for m, u in others if not u.is_demo]
            if real:
                _m, heir = real[0]
                plan["action"] = ACTION_TRANSFER
                plan["new_admin"] = {"id": str(heir.id), "name": heir.name}
            else:
                plan["action"] = ACTION_DELETE
                plan["reason"] = "only_demo_members"
        plans.append(plan)
    return plans


def _plan_line(plan: dict) -> str:
    if plan["action"] == ACTION_DELETE:
        return f"Проект «{plan['name']}» будет удалён."
    if plan["action"] == ACTION_TRANSFER:
        return (
            f"Права администратора в проекте «{plan['name']}» "
            f"перейдут к {plan['new_admin']['name']}."
        )
    return f"Вы выйдете из проекта «{plan['name']}», данные команды сохранятся."


async def plan_account_deletion(db: AsyncSession, user: User) -> dict:
    """Preview for the confirmation dialog. Never mutates data."""
    blocked: dict | None = None
    try:
        _ensure_deletable(user)
        await _ensure_not_last_super_admin(db, user)
    except AccountError as e:
        blocked = {"code": e.code, "message": e.message}
    projects = await plan_project_exits(db, user)
    for p in projects:
        p["summary"] = _plan_line(p)
    return {"can_delete": blocked is None, "blocked": blocked, "projects": projects}


async def exit_projects(
    db: AsyncSession,
    user: User,
    plans: list[dict],
    *,
    notify_reason: str = "Прежний администратор удалил аккаунт, права перешли к вам.",
) -> None:
    """Apply plans from ``plan_project_exits``: transfer admin, delete or leave projects."""
    for p in plans:
        if p["action"] != ACTION_TRANSFER:
            continue
        project_id = uuid.UUID(p["id"])
        heir_id = uuid.UUID(p["new_admin"]["id"])
        await db.execute(
            update(ProjectMember)
            .where(ProjectMember.project_id == project_id, ProjectMember.user_id == heir_id)
            .values(role=ProjectMemberRole.admin)
        )
        await create_in_app(
            db,
            user_id=heir_id,
            actor_id=None,
            kind="project_admin_granted",
            title=f"Вы стали администратором проекта «{p['name']}»",
            body=notify_reason,
            project_id=project_id,
        )

    # Hard-delete projects with no one left (only member / demo-only teammates).
    # Files of deleted projects' tasks are removed from disk as well.
    file_dirs = []
    for p in plans:
        if p["action"] == ACTION_DELETE:
            project_id = uuid.UUID(p["id"])
            file_dirs += await project_attachment_dirs(db, project_id)
            await db.execute(delete(Project).where(Project.id == project_id))
    remove_dirs(file_dirs)

    leave_ids = [uuid.UUID(p["id"]) for p in plans if p["action"] != ACTION_DELETE]
    if leave_ids:
        await db.execute(
            delete(ProjectMember).where(
                ProjectMember.user_id == user.id,
                ProjectMember.project_id.in_(leave_ids),
            )
        )


async def delete_own_account(db: AsyncSession, user: User) -> dict:
    _ensure_deletable(user)
    await _ensure_not_last_super_admin(db, user)

    plans = await plan_project_exits(db, user)
    await exit_projects(db, user, plans)
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
    return {"projects": plans}
