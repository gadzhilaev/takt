import csv
import io
import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import generate_password, hash_password
from app.models.task import AdminAuditLog, Task, TaskAssignee
from app.models.user import User, UserRole
from app.services.auth_service import revoke_all_user_tokens


class AdminError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message


async def audit(
    db: AsyncSession,
    admin_id: uuid.UUID,
    action: str,
    target_user_id: uuid.UUID | None = None,
    details: str | None = None,
) -> None:
    db.add(
        AdminAuditLog(
            admin_id=admin_id,
            target_user_id=target_user_id,
            action=action,
            details=details,
            created_at=datetime.now(UTC),
        )
    )


async def count_active_admins(db: AsyncSession, exclude_id: uuid.UUID | None = None) -> int:
    q = select(func.count()).select_from(User).where(
        User.role == UserRole.admin, User.is_active.is_(True)
    )
    if exclude_id:
        q = q.where(User.id != exclude_id)
    return await db.scalar(q) or 0


async def create_user_admin(
    db: AsyncSession,
    admin: User,
    *,
    name: str,
    email: str,
    role: UserRole,
    password: str | None,
    must_change_password: bool,
) -> tuple[User, str | None]:
    email = email.lower()
    existing = await db.scalar(select(User).where(User.email == email))
    if existing:
        raise AdminError("email_exists", "Пользователь с таким email уже существует")
    temp: str | None = None
    pwd = password or generate_password()
    if not password:
        temp = pwd
    user = User(
        email=email,
        name=name,
        role=role,
        password_hash=hash_password(pwd),
        is_active=True,
        must_change_password=must_change_password,
    )
    db.add(user)
    await db.flush()
    await audit(db, admin.id, "user_created", user.id, f"role={role.value}")
    return user, temp


async def deactivate_user(db: AsyncSession, admin: User, target: User) -> None:
    if target.id == admin.id:
        raise AdminError("self", "Нельзя отключить самого себя")
    if target.role == UserRole.admin and target.is_active:
        others = await count_active_admins(db, exclude_id=target.id)
        if others < 1:
            raise AdminError("last_admin", "Нельзя отключить последнего администратора")
    target.is_active = False
    await revoke_all_user_tokens(db, target.id)
    await audit(db, admin.id, "user_deactivated", target.id)


async def activate_user(db: AsyncSession, admin: User, target: User) -> None:
    target.is_active = True
    await audit(db, admin.id, "user_activated", target.id)


async def delete_user(
    db: AsyncSession,
    admin: User,
    target: User,
    reassign_to: uuid.UUID | None,
) -> None:
    if target.id == admin.id:
        raise AdminError("self", "Нельзя удалить самого себя")
    if target.role == UserRole.admin and target.is_active:
        others = await count_active_admins(db, exclude_id=target.id)
        if others < 1:
            raise AdminError("last_admin", "Нельзя удалить последнего администратора")
    task_count = await db.scalar(
        select(func.count())
        .select_from(TaskAssignee)
        .join(Task)
        .where(TaskAssignee.user_id == target.id, Task.deleted_at.is_(None))
    )
    author_count = await db.scalar(
        select(func.count()).select_from(Task).where(
            Task.author_id == target.id, Task.deleted_at.is_(None)
        )
    )
    if (task_count or author_count) and not reassign_to:
        raise AdminError(
            "has_tasks",
            "У пользователя есть задачи. Укажите пользователя для переназначения или отключите его.",
        )
    if reassign_to:
        reassign_user = await db.get(User, reassign_to)
        if not reassign_user:
            raise AdminError("invalid_reassign", "Пользователь для переназначения не найден")
        await db.execute(
            TaskAssignee.__table__.update()
            .where(TaskAssignee.user_id == target.id)
            .values(user_id=reassign_to)
        )
        await db.execute(
            Task.__table__.update()
            .where(Task.author_id == target.id)
            .values(author_id=reassign_to)
        )
    uid = target.id
    await db.execute(delete(User).where(User.id == uid))
    await audit(db, admin.id, "user_deleted", uid)


def parse_users_csv(content: str) -> list[dict[str, str]]:
    reader = csv.DictReader(io.StringIO(content))
    rows = []
    for row in reader:
        name = (row.get("name") or row.get("имя") or "").strip()
        email = (row.get("email") or row.get("Email") or "").strip()
        role = (row.get("role") or row.get("роль") or "member").strip().lower()
        if name and email:
            rows.append({"name": name, "email": email, "role": role})
    return rows
