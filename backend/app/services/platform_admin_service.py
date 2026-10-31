"""Platform-wide admin queries — no private task bodies for project lists."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import and_, delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.platform import (
    ModerationAction,
    ModerationReport,
    ModerationReportStatus,
    PlatformSetting,
    ProjectRestriction,
    UserActivityEvent,
    UserBlock,
    UserIdentity,
)
from app.models.auth import RefreshToken
from app.models.project import Project, ProjectMember
from app.models.task import (
    ActivityLog,
    AdminAuditLog,
    Attachment,
    Comment,
    Task,
    TaskAssignee,
)
from app.models.user import PLATFORM_ROLE_RANK, PlatformRole, User, UserRole
from app.services import admin_service
from app.services.auth_service import revoke_all_user_tokens


class PlatformError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code


async def dashboard_stats(db: AsyncSession) -> dict:
    now = datetime.now(UTC)
    day = now - timedelta(days=1)
    week = now - timedelta(days=7)
    month = now - timedelta(days=30)

    users_total = await db.scalar(select(func.count()).select_from(User)) or 0
    users_new_7d = await db.scalar(
        select(func.count()).select_from(User).where(User.created_at >= week)
    ) or 0
    projects_total = await db.scalar(select(func.count()).select_from(Project)) or 0
    tasks_total = await db.scalar(
        select(func.count()).select_from(Task).where(Task.deleted_at.is_(None))
    ) or 0
    open_reports = await db.scalar(
        select(func.count())
        .select_from(ModerationReport)
        .where(ModerationReport.status.in_([ModerationReportStatus.open, ModerationReportStatus.in_review]))
    ) or 0
    active_blocks = await db.scalar(
        select(func.count())
        .select_from(User)
        .where(
            or_(
                and_(User.blocked_until.is_not(None), User.blocked_until > now),
                User.is_active.is_(False),
            )
        )
    ) or 0

    async def distinct_active(since: datetime) -> int:
        return (
            await db.scalar(
                select(func.count(func.distinct(UserActivityEvent.user_id))).where(
                    UserActivityEvent.created_at >= since,
                    UserActivityEvent.event_type.in_(["login", "login_oauth", "session"]),
                )
            )
            or 0
        )

    # Fallback: last_login_at when activity table is sparse
    dau_events = await distinct_active(day)
    wau_events = await distinct_active(week)
    mau_events = await distinct_active(month)
    dau_login = await db.scalar(
        select(func.count()).select_from(User).where(User.last_login_at >= day)
    ) or 0
    wau_login = await db.scalar(
        select(func.count()).select_from(User).where(User.last_login_at >= week)
    ) or 0
    mau_login = await db.scalar(
        select(func.count()).select_from(User).where(User.last_login_at >= month)
    ) or 0

    activity_by_day = (
        await db.execute(
            select(
                func.date_trunc("day", UserActivityEvent.created_at).label("day"),
                func.count().label("cnt"),
            )
            .where(UserActivityEvent.created_at >= now - timedelta(days=14))
            .group_by("day")
            .order_by("day")
        )
    ).all()

    return {
        "users_total": users_total,
        "users_new_7d": users_new_7d,
        "projects_total": projects_total,
        "tasks_total": tasks_total,
        "open_reports": open_reports,
        "active_blocks": active_blocks,
        "dau": max(dau_events, dau_login),
        "wau": max(wau_events, wau_login),
        "mau": max(mau_events, mau_login),
        "activity_by_day": [
            {"day": r.day.date().isoformat() if r.day else None, "count": r.cnt}
            for r in activity_by_day
        ],
        "metrics_note": (
            "Активность — уникальные пользователи, которые входили в систему "
            "(события входа или поле «последний вход»). Цифры из базы, без заглушек."
        ),
    }


_USER_SORT = {
    "name": User.name,
    "email": User.email,
    "role": User.platform_role,
    "created_at": User.created_at,
    "last_login_at": User.last_login_at,
}


async def list_users(
    db: AsyncSession,
    *,
    q: str | None,
    status: str | None,
    registered_from: datetime | None,
    registered_to: datetime | None,
    page: int,
    page_size: int,
    sort: str | None = None,
    sort_dir: str | None = None,
) -> dict:
    page = max(1, page)
    page_size = min(100, max(1, page_size))
    stmt = select(User)
    if q:
        like = f"%{q.strip()}%"
        try:
            uid = uuid.UUID(q.strip())
            stmt = stmt.where(or_(User.id == uid, User.name.ilike(like), User.email.ilike(like)))
        except ValueError:
            stmt = stmt.where(or_(User.name.ilike(like), User.email.ilike(like)))
    now = datetime.now(UTC)
    if status == "active":
        stmt = stmt.where(User.is_active.is_(True), or_(User.blocked_until.is_(None), User.blocked_until <= now))
    elif status == "blocked":
        stmt = stmt.where(or_(User.is_active.is_(False), and_(User.blocked_until.is_not(None), User.blocked_until > now)))
    elif status == "inactive":
        stmt = stmt.where(User.is_active.is_(False))
    if registered_from:
        stmt = stmt.where(User.created_at >= registered_from)
    if registered_to:
        stmt = stmt.where(User.created_at <= registered_to)

    total = await db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    col = _USER_SORT.get(sort or "created_at", User.created_at)
    ascending = (sort_dir or "desc").lower() == "asc"
    order = col.asc().nulls_last() if ascending else col.desc().nulls_last()
    rows = (
        await db.execute(stmt.order_by(order).offset((page - 1) * page_size).limit(page_size))
    ).scalars().all()

    providers_by_user: dict[uuid.UUID, list[str]] = {u.id: [] for u in rows}
    if rows:
        idents = (
            await db.execute(
                select(UserIdentity).where(UserIdentity.user_id.in_([u.id for u in rows]))
            )
        ).scalars().all()
        for ident in idents:
            providers_by_user.setdefault(ident.user_id, []).append(ident.provider.value)

    return {
        "items": [
            _user_row(u, oauth_providers=providers_by_user.get(u.id, [])) for u in rows
        ],
        "page": page,
        "page_size": page_size,
        "total": total,
        "sort": sort or "created_at",
        "sort_dir": "asc" if ascending else "desc",
    }


def _user_row(u: User, *, oauth_providers: list[str] | None = None) -> dict:
    methods: list[str] = []
    if u.password_hash:
        methods.append("email")
    for p in oauth_providers or []:
        if p not in methods:
            methods.append(p)
    return {
        "id": str(u.id),
        "email": u.email,
        "name": u.name,
        "role": u.role.value,
        "platform_role": u.platform_role.value if u.platform_role else "none",
        "is_active": u.is_active,
        "is_demo": u.is_demo,
        "created_at": u.created_at.isoformat() if u.created_at else None,
        "last_login_at": u.last_login_at.isoformat() if u.last_login_at else None,
        "blocked_until": u.blocked_until.isoformat() if u.blocked_until else None,
        "block_reason": u.block_reason,
        "has_password": bool(u.password_hash),
        "must_change_password": bool(u.must_change_password),
        "login_methods": methods,
    }


async def user_detail(db: AsyncSession, user_id: uuid.UUID) -> dict:
    user = await db.get(User, user_id)
    if not user:
        raise PlatformError("not_found", "Пользователь не найден", 404)
    identities = (
        await db.execute(select(UserIdentity).where(UserIdentity.user_id == user_id))
    ).scalars().all()
    memberships = (
        await db.execute(
            select(ProjectMember, Project)
            .join(Project, Project.id == ProjectMember.project_id)
            .where(ProjectMember.user_id == user_id)
        )
    ).all()
    audits = (
        await db.execute(
            select(AdminAuditLog)
            .where(AdminAuditLog.target_user_id == user_id)
            .order_by(AdminAuditLog.created_at.desc())
            .limit(50)
        )
    ).scalars().all()
    return {
        "user": _user_row(user, oauth_providers=[i.provider.value for i in identities]),
        "identities": [
            {
                "provider": i.provider.value,
                "email": i.email,
                "linked_at": i.linked_at.isoformat() if i.linked_at else None,
            }
            for i in identities
        ],
        "projects": [
            {
                "id": str(p.id),
                "name": p.name,
                "role": m.role.value,
                "is_demo": p.is_demo,
                "is_archived": p.is_archived,
            }
            for m, p in memberships
        ],
        "admin_actions": [
            {
                "id": str(a.id),
                "action": a.action,
                "details": a.details,
                "admin_id": str(a.admin_id),
                "created_at": a.created_at.isoformat() if a.created_at else None,
            }
            for a in audits
        ],
    }


async def block_user(
    db: AsyncSession,
    admin: User,
    target_id: uuid.UUID,
    *,
    reason: str,
    until: datetime | None,
) -> User:
    target = await db.get(User, target_id)
    if not target:
        raise PlatformError("not_found", "Не найден", 404)
    if target.id == admin.id:
        raise PlatformError("self", "Нельзя ограничить себя")
    if PLATFORM_ROLE_RANK[target.platform_role] >= PLATFORM_ROLE_RANK[PlatformRole.admin]:
        if PLATFORM_ROLE_RANK[admin.platform_role] < PLATFORM_ROLE_RANK[PlatformRole.super_admin]:
            raise PlatformError("forbidden", "Только super_admin может ограничивать администраторов")
    target.blocked_until = until
    target.block_reason = reason[:2000]
    if until is None:
        # permanent-style block also deactivates
        target.is_active = False
    db.add(
        UserBlock(
            id=uuid.uuid4(),
            user_id=target.id,
            created_by_id=admin.id,
            reason=reason[:2000],
            blocked_until=until,
        )
    )
    await revoke_all_user_tokens(db, target.id)
    await admin_service.audit(db, admin.id, "user_blocked", target.id, reason[:500])
    await db.flush()
    return target


async def unblock_user(db: AsyncSession, admin: User, target_id: uuid.UUID) -> User:
    target = await db.get(User, target_id)
    if not target:
        raise PlatformError("not_found", "Не найден", 404)
    target.blocked_until = None
    target.block_reason = None
    target.is_active = True
    open_blocks = (
        await db.execute(
            select(UserBlock).where(UserBlock.user_id == target_id, UserBlock.lifted_at.is_(None))
        )
    ).scalars().all()
    now = datetime.now(UTC)
    for b in open_blocks:
        b.lifted_at = now
        b.lifted_by_id = admin.id
    await admin_service.audit(db, admin.id, "user_unblocked", target.id)
    await db.flush()
    return target


async def set_platform_role(db: AsyncSession, admin: User, target_id: uuid.UUID, role: PlatformRole) -> User:
    if PLATFORM_ROLE_RANK[admin.platform_role] < PLATFORM_ROLE_RANK[PlatformRole.super_admin]:
        raise PlatformError("forbidden", "Только super_admin назначает роли", 403)
    target = await db.get(User, target_id)
    if not target:
        raise PlatformError("not_found", "Не найден", 404)
    if target.id == admin.id and role != PlatformRole.super_admin:
        raise PlatformError("self", "Нельзя снять с себя super_admin этим методом")
    target.platform_role = role
    # Keep legacy role in sync for existing /api/v1/admin
    if PLATFORM_ROLE_RANK[role] >= PLATFORM_ROLE_RANK[PlatformRole.admin]:
        target.role = UserRole.admin
    elif target.role == UserRole.admin and role == PlatformRole.none:
        target.role = UserRole.member
    await admin_service.audit(db, admin.id, "platform_role_set", target.id, f"role={role.value}")
    await db.flush()
    return target


def _assert_can_manage(admin: User, target: User, *, action: str) -> None:
    if target.id == admin.id and action == "delete":
        raise PlatformError("self", "Нельзя удалить свой аккаунт")
    admin_rank = PLATFORM_ROLE_RANK[admin.platform_role or PlatformRole.none]
    target_rank = PLATFORM_ROLE_RANK[target.platform_role or PlatformRole.none]
    if target_rank >= PLATFORM_ROLE_RANK[PlatformRole.admin] and admin_rank < PLATFORM_ROLE_RANK[
        PlatformRole.super_admin
    ]:
        raise PlatformError(
            "forbidden",
            "Только super_admin может изменять или удалять администраторов",
            403,
        )
    if target_rank > admin_rank:
        raise PlatformError("forbidden", "Нельзя управлять пользователем с более высокой ролью", 403)


async def update_user(
    db: AsyncSession,
    admin: User,
    target_id: uuid.UUID,
    *,
    name: str | None = None,
    email: str | None = None,
    is_active: bool | None = None,
    must_change_password: bool | None = None,
    password: str | None = None,
    platform_role: PlatformRole | None = None,
) -> User:
    target = await db.get(User, target_id)
    if not target:
        raise PlatformError("not_found", "Пользователь не найден", 404)
    _assert_can_manage(admin, target, action="update")

    changes: list[str] = []
    if name is not None:
        clean = name.strip()
        if len(clean) < 1 or len(clean) > 200:
            raise PlatformError("bad_name", "Имя должно быть от 1 до 200 символов")
        if clean != target.name:
            target.name = clean
            changes.append("name")
    if email is not None:
        clean_email = email.strip().lower()
        if "@" not in clean_email or len(clean_email) > 320:
            raise PlatformError("bad_email", "Некорректный email")
        if clean_email != target.email:
            taken = await db.scalar(
                select(User.id).where(User.email == clean_email, User.id != target.id)
            )
            if taken:
                raise PlatformError("email_taken", "Email уже занят", 409)
            target.email = clean_email
            changes.append("email")
    if is_active is not None and is_active != target.is_active:
        if target.id == admin.id and not is_active:
            raise PlatformError("self", "Нельзя деактивировать себя")
        target.is_active = is_active
        if is_active:
            target.blocked_until = None
            target.block_reason = None
        changes.append("is_active")
    if must_change_password is not None and must_change_password != target.must_change_password:
        target.must_change_password = must_change_password
        changes.append("must_change_password")
    if password is not None:
        if len(password) < 8 or len(password) > 128:
            raise PlatformError("bad_password", "Пароль должен быть от 8 до 128 символов")
        target.password_hash = hash_password(password)
        changes.append("password")
        await revoke_all_user_tokens(db, target.id)
    if platform_role is not None and platform_role != target.platform_role:
        if PLATFORM_ROLE_RANK[admin.platform_role or PlatformRole.none] < PLATFORM_ROLE_RANK[
            PlatformRole.super_admin
        ]:
            raise PlatformError("forbidden", "Только super_admin назначает роли", 403)
        if target.id == admin.id and platform_role != PlatformRole.super_admin:
            raise PlatformError("self", "Нельзя снять с себя super_admin")
        target.platform_role = platform_role
        if PLATFORM_ROLE_RANK[platform_role] >= PLATFORM_ROLE_RANK[PlatformRole.admin]:
            target.role = UserRole.admin
        elif target.role == UserRole.admin and platform_role == PlatformRole.none:
            target.role = UserRole.member
        changes.append(f"platform_role={platform_role.value}")

    if not changes:
        return target
    await admin_service.audit(
        db, admin.id, "user_updated", target.id, ", ".join(changes)[:500]
    )
    await db.flush()
    return target


async def delete_user(db: AsyncSession, admin: User, target_id: uuid.UUID) -> None:
    target = await db.get(User, target_id)
    if not target:
        raise PlatformError("not_found", "Пользователь не найден", 404)
    _assert_can_manage(admin, target, action="delete")
    if target.platform_role == PlatformRole.super_admin:
        others = await db.scalar(
            select(func.count())
            .select_from(User)
            .where(User.platform_role == PlatformRole.super_admin, User.id != target.id)
        )
        if not others:
            raise PlatformError("last_super_admin", "Нельзя удалить последнего суперадмина")

    await revoke_all_user_tokens(db, target.id)
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == target.id))

    # Reassign non-cascading FK references to the acting admin, then delete.
    await db.execute(
        update(Task).where(Task.author_id == target.id).values(author_id=admin.id)
    )
    await db.execute(delete(TaskAssignee).where(TaskAssignee.user_id == target.id))
    await db.execute(
        update(Comment).where(Comment.author_id == target.id).values(author_id=admin.id)
    )
    await db.execute(
        update(Attachment)
        .where(Attachment.uploaded_by_id == target.id)
        .values(uploaded_by_id=admin.id)
    )
    await db.execute(
        update(ActivityLog).where(ActivityLog.user_id == target.id).values(user_id=admin.id)
    )
    await db.execute(
        update(AdminAuditLog)
        .where(AdminAuditLog.target_user_id == target.id)
        .values(target_user_id=None)
    )
    await db.execute(
        update(AdminAuditLog)
        .where(AdminAuditLog.admin_id == target.id)
        .values(admin_id=admin.id)
    )
    await db.execute(
        update(UserBlock)
        .where(UserBlock.created_by_id == target.id)
        .values(created_by_id=admin.id)
    )
    await db.execute(
        update(UserBlock)
        .where(UserBlock.lifted_by_id == target.id)
        .values(lifted_by_id=None)
    )
    await db.execute(delete(UserBlock).where(UserBlock.user_id == target.id))
    await db.execute(
        update(ProjectRestriction)
        .where(ProjectRestriction.created_by_id == target.id)
        .values(created_by_id=admin.id)
    )
    await db.execute(
        update(ModerationReport)
        .where(ModerationReport.assignee_id == target.id)
        .values(assignee_id=None)
    )
    await db.execute(
        update(ModerationReport)
        .where(ModerationReport.decided_by_id == target.id)
        .values(decided_by_id=None)
    )
    await db.execute(
        update(ModerationAction)
        .where(ModerationAction.actor_id == target.id)
        .values(actor_id=admin.id)
    )
    await db.execute(
        update(PlatformSetting)
        .where(PlatformSetting.updated_by_id == target.id)
        .values(updated_by_id=None)
    )

    email_snapshot = target.email
    tid = target.id
    await admin_service.audit(
        db, admin.id, "user_deleted", None, f"email={email_snapshot}; id={tid}"
    )
    # Core DELETE avoids ORM nullifying non-nullable FKs via relationships.
    await db.execute(delete(User).where(User.id == tid))
    await db.flush()


_PROJECT_SORT = {
    "name": Project.name,
    "created_at": Project.created_at,
}


async def list_projects(
    db: AsyncSession,
    *,
    q: str | None,
    page: int,
    page_size: int,
    sort: str | None = None,
    sort_dir: str | None = None,
) -> dict:
    page = max(1, page)
    page_size = min(100, max(1, page_size))
    stmt = select(Project)
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(Project.name.ilike(like))
    total = await db.scalar(select(func.count()).select_from(stmt.subquery())) or 0

    member_count_sq = (
        select(func.count())
        .select_from(ProjectMember)
        .where(ProjectMember.project_id == Project.id)
        .correlate(Project)
        .scalar_subquery()
    )
    task_count_sq = (
        select(func.count())
        .select_from(Task)
        .where(Task.project_id == Project.id, Task.deleted_at.is_(None))
        .correlate(Project)
        .scalar_subquery()
    )
    restricted_sq = (
        select(func.count())
        .select_from(ProjectRestriction)
        .where(ProjectRestriction.project_id == Project.id, ProjectRestriction.active.is_(True))
        .correlate(Project)
        .scalar_subquery()
    )

    sort_key = sort or "created_at"
    ascending = (sort_dir or "desc").lower() == "asc"
    if sort_key == "member_count":
        col = member_count_sq
    elif sort_key == "task_count":
        col = task_count_sq
    elif sort_key == "restricted":
        col = restricted_sq
    else:
        col = _PROJECT_SORT.get(sort_key, Project.created_at)
    order = col.asc().nulls_last() if ascending else col.desc().nulls_last()

    projects = (
        await db.execute(stmt.order_by(order).offset((page - 1) * page_size).limit(page_size))
    ).scalars().all()
    items = []
    for p in projects:
        member_count = await db.scalar(
            select(func.count()).select_from(ProjectMember).where(ProjectMember.project_id == p.id)
        ) or 0
        task_count = await db.scalar(
            select(func.count())
            .select_from(Task)
            .where(Task.project_id == p.id, Task.deleted_at.is_(None))
        ) or 0
        restriction = await db.scalar(
            select(ProjectRestriction).where(
                ProjectRestriction.project_id == p.id, ProjectRestriction.active.is_(True)
            )
        )
        # Owner ≈ first admin member
        owner = await db.scalar(
            select(User)
            .join(ProjectMember, ProjectMember.user_id == User.id)
            .where(ProjectMember.project_id == p.id)
            .order_by(ProjectMember.created_at.asc())
            .limit(1)
        )
        items.append(
            {
                "id": str(p.id),
                "name": p.name,
                "is_demo": p.is_demo,
                "is_archived": p.is_archived,
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "member_count": member_count,
                "task_count": task_count,
                "restricted": bool(restriction),
                "restriction_reason": restriction.reason if restriction else None,
                "owner": (
                    {"id": str(owner.id), "name": owner.name, "email": owner.email}
                    if owner
                    else None
                ),
                # Explicitly no task titles/bodies
                "content_access": "metadata_only",
            }
        )
    return {
        "items": items,
        "page": page,
        "page_size": page_size,
        "total": total,
        "sort": sort_key,
        "sort_dir": "asc" if ascending else "desc",
    }


async def project_detail(db: AsyncSession, project_id: uuid.UUID) -> dict:
    project = await db.get(Project, project_id)
    if not project:
        raise PlatformError("not_found", "Проект не найден", 404)
    member_count = await db.scalar(
        select(func.count()).select_from(ProjectMember).where(ProjectMember.project_id == project.id)
    ) or 0
    task_count = await db.scalar(
        select(func.count())
        .select_from(Task)
        .where(Task.project_id == project.id, Task.deleted_at.is_(None))
    ) or 0
    restriction = await db.scalar(
        select(ProjectRestriction).where(
            ProjectRestriction.project_id == project.id, ProjectRestriction.active.is_(True)
        )
    )
    rows = (
        await db.execute(
            select(ProjectMember, User)
            .join(User, User.id == ProjectMember.user_id)
            .where(ProjectMember.project_id == project.id)
            .order_by(ProjectMember.created_at.asc())
        )
    ).all()
    return {
        "id": str(project.id),
        "name": project.name,
        "is_demo": project.is_demo,
        "is_archived": project.is_archived,
        "created_at": project.created_at.isoformat() if project.created_at else None,
        "member_count": member_count,
        "task_count": task_count,
        "restricted": bool(restriction),
        "restriction_reason": restriction.reason if restriction else None,
        "members": [
            {
                "user_id": str(u.id),
                "name": u.name,
                "email": u.email,
                "role": m.role.value,
                "joined_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m, u in rows
        ],
        "content_access": "metadata_only",
    }


async def restrict_project(db: AsyncSession, admin: User, project_id: uuid.UUID, reason: str) -> dict:
    project = await db.get(Project, project_id)
    if not project:
        raise PlatformError("not_found", "Проект не найден", 404)
    existing = await db.scalar(
        select(ProjectRestriction).where(ProjectRestriction.project_id == project_id)
    )
    if existing:
        existing.active = True
        existing.reason = reason[:2000]
        existing.lifted_at = None
        existing.created_by_id = admin.id
    else:
        db.add(
            ProjectRestriction(
                id=uuid.uuid4(),
                project_id=project_id,
                reason=reason[:2000],
                created_by_id=admin.id,
                active=True,
            )
        )
    await admin_service.audit(db, admin.id, "project_restricted", None, f"project={project_id}")
    await db.flush()
    return {"ok": True}


async def unrestrict_project(db: AsyncSession, admin: User, project_id: uuid.UUID) -> dict:
    project = await db.get(Project, project_id)
    if not project:
        raise PlatformError("not_found", "Проект не найден", 404)
    existing = await db.scalar(
        select(ProjectRestriction).where(ProjectRestriction.project_id == project_id)
    )
    if existing and existing.active:
        existing.active = False
        existing.lifted_at = datetime.now(UTC)
        await admin_service.audit(
            db, admin.id, "project_unrestricted", None, f"project={project_id}"
        )
        await db.flush()
    return {"ok": True}


async def analytics(db: AsyncSession, days: int = 30) -> dict:
    days = min(90, max(7, days))
    since = datetime.now(UTC) - timedelta(days=days)
    regs = (
        await db.execute(
            select(func.date_trunc("day", User.created_at).label("day"), func.count())
            .where(User.created_at >= since)
            .group_by("day")
            .order_by("day")
        )
    ).all()
    projects = (
        await db.execute(
            select(func.date_trunc("day", Project.created_at).label("day"), func.count())
            .where(Project.created_at >= since)
            .group_by("day")
            .order_by("day")
        )
    ).all()
    tasks_created = (
        await db.execute(
            select(func.date_trunc("day", Task.created_at).label("day"), func.count())
            .where(Task.created_at >= since, Task.deleted_at.is_(None))
            .group_by("day")
            .order_by("day")
        )
    ).all()
    # Completion: tasks moved to done statuses approximated by updated_at on is_done — not perfect;
    # only report if we have clear data. Use ActivityLog if available — skip inventing.
    return {
        "days": days,
        "registrations": [{"day": r[0].date().isoformat(), "count": r[1]} for r in regs if r[0]],
        "projects_created": [{"day": r[0].date().isoformat(), "count": r[1]} for r in projects if r[0]],
        "tasks_created": [{"day": r[0].date().isoformat(), "count": r[1]} for r in tasks_created if r[0]],
        "tasks_completed": None,
        "retention": None,
        "note": (
            "Показаны только факты из базы: регистрации, новые проекты и созданные задачи. "
            "Завершение задач и удержание пока не считаем — нет надёжных событий."
        ),
    }


async def system_health(db: AsyncSession, settings) -> dict:
    from app.services.email_service import is_email_configured
    from app.services.oauth_service import provider_availability

    return {
        "backend": "ok",
        "database": "ok",
        "email": {
            "configured": is_email_configured(),
            "from": settings.SMTP_FROM_EMAIL.split("<")[-1].rstrip(">") if settings.SMTP_FROM_EMAIL else None,
        },
        "web_push": {
            "configured": bool(settings.VAPID_PUBLIC_KEY and settings.VAPID_PRIVATE_KEY),
        },
        "fcm": {
            "enabled": bool(settings.FCM_ENABLED),
            "credentials_configured": bool(settings.FIREBASE_CREDENTIALS_FILE),
        },
        "oauth": {
            k: {"enabled": v["enabled"], "configured": v["configured"]}
            for k, v in (await provider_availability(db, settings))["providers"].items()
        },
        "background_jobs": {
            "note": "Отдельной очереди ошибок фоновых задач пока нет — показатель не выдуман.",
            "available": False,
        },
    }


async def get_settings_map(db: AsyncSession) -> dict:
    rows = (await db.execute(select(PlatformSetting))).scalars().all()
    return {r.key: r.value for r in rows}


async def put_setting(db: AsyncSession, admin: User, key: str, value: dict) -> dict:
    row = await db.get(PlatformSetting, key)
    if row:
        row.value = value
        row.updated_by_id = admin.id
    else:
        db.add(PlatformSetting(key=key, value=value, updated_by_id=admin.id))
    await admin_service.audit(db, admin.id, "platform_setting", None, key)
    await db.flush()
    return {"key": key, "value": value}


async def decide_report(
    db: AsyncSession,
    actor: User,
    report_id: uuid.UUID,
    *,
    action: str,
    note: str | None,
    expected_version: int,
) -> ModerationReport:
    report = await db.get(ModerationReport, report_id)
    if not report:
        raise PlatformError("not_found", "Жалоба не найдена", 404)
    if report.version != expected_version:
        raise PlatformError("conflict", "Жалоба уже изменена другим модератором", 409)
    terminal = {
        ModerationReportStatus.resolved_warning,
        ModerationReportStatus.resolved_restriction,
        ModerationReportStatus.rejected,
        ModerationReportStatus.closed,
    }
    if report.status in terminal and action not in ("appeal", "reopen"):
        raise PlatformError("already_decided", "Жалоба уже закрыта")

    status_map = {
        "assign_self": ModerationReportStatus.in_review,
        "warn": ModerationReportStatus.resolved_warning,
        "restrict": ModerationReportStatus.resolved_restriction,
        "reject": ModerationReportStatus.rejected,
        "appeal": ModerationReportStatus.appealed,
        "close": ModerationReportStatus.closed,
    }
    if action not in status_map and action != "assign_self":
        raise PlatformError("bad_action", "Неизвестное действие")

    if action == "assign_self":
        report.assignee_id = actor.id
        report.status = ModerationReportStatus.in_review
    else:
        report.status = status_map[action]
        report.decision_note = (note or "")[:2000] or None
        report.decided_by_id = actor.id
        report.decided_at = datetime.now(UTC)
    report.version += 1
    db.add(
        ModerationAction(
            id=uuid.uuid4(),
            report_id=report.id,
            actor_id=actor.id,
            action=action,
            note=note,
            created_at=datetime.now(UTC),
        )
    )
    await admin_service.audit(db, actor.id, f"moderation_{action}", None, str(report.id))
    await db.flush()
    return report
