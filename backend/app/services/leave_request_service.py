import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.leave_request import ProjectLeaveRequest, ProjectLeaveRequestStatus
from app.models.notification import Notification
from app.models.project import ProjectMember, ProjectMemberRole
from app.models.user import User
from app.services import project_service


class LeaveRequestError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


async def _admin_user_ids(db: AsyncSession, project_id: uuid.UUID) -> list[uuid.UUID]:
    rows = (
        await db.execute(
            select(ProjectMember.user_id).where(
                ProjectMember.project_id == project_id,
                ProjectMember.role == ProjectMemberRole.admin,
            )
        )
    ).scalars().all()
    return list(rows)


async def remove_member(
    db: AsyncSession,
    *,
    project_id: uuid.UUID,
    target_user_id: uuid.UUID,
    actor: User,
) -> None:
    # Any member (not viewer) can remove others; only admins can remove an admin.
    actor_role = await project_service.ensure_project_access(
        db, actor, project_id, min_role=ProjectMemberRole.member
    )
    if target_user_id == actor.id:
        raise LeaveRequestError("self", "Нельзя удалить себя этим действием")

    target = await db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == target_user_id,
        )
    )
    if target is None:
        raise LeaveRequestError("not_found", "Участник не найден")
    if target.role == ProjectMemberRole.admin:
        if actor_role != ProjectMemberRole.admin:
            raise PermissionError("Только владелец может удалить другого владельца")
        admins = await _admin_user_ids(db, project_id)
        if len(admins) <= 1:
            raise LeaveRequestError("last_admin", "Нельзя удалить единственного владельца")

    await db.execute(
        delete(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == target_user_id,
        )
    )
    # Cancel pending leave requests for this user.
    pending = (
        await db.execute(
            select(ProjectLeaveRequest).where(
                ProjectLeaveRequest.project_id == project_id,
                ProjectLeaveRequest.user_id == target_user_id,
                ProjectLeaveRequest.status == ProjectLeaveRequestStatus.pending,
            )
        )
    ).scalars().all()
    now = datetime.now(UTC)
    for req in pending:
        req.status = ProjectLeaveRequestStatus.cancelled
        req.responded_at = now

    project = await project_service.get_project(db, project_id)
    db.add(
        Notification(
            user_id=target_user_id,
            actor_id=actor.id,
            project_id=project_id,
            kind="member_removed",
            title="Вас удалили из проекта",
            body=f"{actor.name} удалил(а) вас из «{project.name if project else 'проекта'}»",
            created_at=now,
            is_read=False,
        )
    )


async def leave_project_now(
    db: AsyncSession,
    *,
    project_id: uuid.UUID,
    user: User,
) -> None:
    """Member leaves immediately (no approval). Sole admin cannot leave."""
    role = await project_service.ensure_project_access(
        db, user, project_id, min_role=ProjectMemberRole.viewer
    )
    if role == ProjectMemberRole.admin:
        admins = await _admin_user_ids(db, project_id)
        if len(admins) <= 1:
            raise LeaveRequestError(
                "last_admin",
                "Единственный владелец не может покинуть проект — "
                "удалите его или назначьте другого владельца",
            )

    await db.execute(
        delete(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == user.id,
        )
    )
    pending = (
        await db.execute(
            select(ProjectLeaveRequest).where(
                ProjectLeaveRequest.project_id == project_id,
                ProjectLeaveRequest.user_id == user.id,
                ProjectLeaveRequest.status == ProjectLeaveRequestStatus.pending,
            )
        )
    ).scalars().all()
    now = datetime.now(UTC)
    for req in pending:
        req.status = ProjectLeaveRequestStatus.cancelled
        req.responded_at = now


async def create_leave_request(
    db: AsyncSession,
    *,
    project_id: uuid.UUID,
    user: User,
) -> ProjectLeaveRequest:
    role = await project_service.ensure_project_access(
        db, user, project_id, min_role=ProjectMemberRole.viewer
    )
    if role == ProjectMemberRole.admin:
        admins = await _admin_user_ids(db, project_id)
        if len(admins) <= 1:
            raise LeaveRequestError(
                "last_admin",
                "Единственный владелец не может покинуть проект",
            )

    existing = await db.scalar(
        select(ProjectLeaveRequest).where(
            ProjectLeaveRequest.project_id == project_id,
            ProjectLeaveRequest.user_id == user.id,
            ProjectLeaveRequest.status == ProjectLeaveRequestStatus.pending,
        )
    )
    if existing:
        raise LeaveRequestError("already_pending", "Заявка уже отправлена")

    now = datetime.now(UTC)
    req = ProjectLeaveRequest(
        project_id=project_id,
        user_id=user.id,
        status=ProjectLeaveRequestStatus.pending,
        created_at=now,
    )
    db.add(req)
    await db.flush()

    project = await project_service.get_project(db, project_id)
    for admin_id in await _admin_user_ids(db, project_id):
        if admin_id == user.id:
            continue
        db.add(
            Notification(
                user_id=admin_id,
                actor_id=user.id,
                project_id=project_id,
                kind="leave_request",
                title="Заявка на выход из проекта",
                body=(
                    f"{user.name} просит удалить его из "
                    f"«{project.name if project else 'проекта'}»"
                ),
                created_at=now,
                is_read=False,
            )
        )
    return req


async def list_leave_requests(
    db: AsyncSession,
    *,
    project_id: uuid.UUID,
    user: User,
    pending_only: bool = True,
) -> list[ProjectLeaveRequest]:
    await project_service.ensure_project_access(
        db, user, project_id, min_role=ProjectMemberRole.admin
    )
    q = select(ProjectLeaveRequest).where(ProjectLeaveRequest.project_id == project_id)
    if pending_only:
        q = q.where(ProjectLeaveRequest.status == ProjectLeaveRequestStatus.pending)
    q = q.order_by(ProjectLeaveRequest.created_at.desc())
    return list((await db.execute(q)).scalars().all())


async def approve_leave_request(
    db: AsyncSession,
    *,
    project_id: uuid.UUID,
    request_id: uuid.UUID,
    actor: User,
) -> None:
    await project_service.ensure_project_access(
        db, actor, project_id, min_role=ProjectMemberRole.admin
    )
    req = await db.get(ProjectLeaveRequest, request_id)
    if req is None or req.project_id != project_id:
        raise LeaveRequestError("not_found", "Заявка не найдена")
    if req.status != ProjectLeaveRequestStatus.pending:
        raise LeaveRequestError("not_pending", "Заявка уже обработана")

    now = datetime.now(UTC)
    await db.execute(
        delete(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == req.user_id,
        )
    )
    req.status = ProjectLeaveRequestStatus.approved
    req.responded_at = now

    project = await project_service.get_project(db, project_id)
    db.add(
        Notification(
            user_id=req.user_id,
            actor_id=actor.id,
            project_id=project_id,
            kind="leave_approved",
            title="Заявка одобрена",
            body=f"Вас удалили из «{project.name if project else 'проекта'}»",
            created_at=now,
            is_read=False,
        )
    )


async def reject_leave_request(
    db: AsyncSession,
    *,
    project_id: uuid.UUID,
    request_id: uuid.UUID,
    actor: User,
) -> None:
    await project_service.ensure_project_access(
        db, actor, project_id, min_role=ProjectMemberRole.admin
    )
    req = await db.get(ProjectLeaveRequest, request_id)
    if req is None or req.project_id != project_id:
        raise LeaveRequestError("not_found", "Заявка не найдена")
    if req.status != ProjectLeaveRequestStatus.pending:
        raise LeaveRequestError("not_pending", "Заявка уже обработана")

    now = datetime.now(UTC)
    req.status = ProjectLeaveRequestStatus.rejected
    req.responded_at = now

    project = await project_service.get_project(db, project_id)
    db.add(
        Notification(
            user_id=req.user_id,
            actor_id=actor.id,
            project_id=project_id,
            kind="leave_rejected",
            title="Заявка отклонена",
            body=f"Заявку на выход из «{project.name if project else 'проекта'}» отклонили",
            created_at=now,
            is_read=False,
        )
    )
