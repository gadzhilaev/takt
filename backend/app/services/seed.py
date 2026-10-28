from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.task import Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User, UserRole


async def seed_demo(db: AsyncSession) -> None:
    if await db.scalar(select(User.id).limit(1)):
        existing = await db.scalar(select(User).where(User.email == "member@example.com"))
        if existing:
            return
    member = User(
        email="member@example.com",
        name="Иван Участник",
        role=UserRole.member,
        password_hash=hash_password("Member123!"),
        is_active=True,
        must_change_password=False,
    )
    db.add(member)
    await db.flush()
    statuses = (await db.execute(select(TaskStatus).order_by(TaskStatus.position))).scalars().all()
    if not statuses:
        return
    backlog = statuses[0]
    in_progress = statuses[2] if len(statuses) > 2 else statuses[0]
    task = Task(
        title="Демо: настроить доску",
        description="<p>Пример задачи для команды</p>",
        status_id=in_progress.id,
        priority=TaskPriority.high,
        author_id=member.id,
        due_date=datetime.now(UTC) + timedelta(days=3),
        position=1024,
    )
    db.add(task)
    await db.flush()
    db.add(TaskAssignee(task_id=task.id, user_id=member.id))
    t2 = Task(
        title="Демо: в бэклоге",
        status_id=backlog.id,
        priority=TaskPriority.medium,
        author_id=member.id,
        position=1024,
    )
    db.add(t2)
    await db.commit()
