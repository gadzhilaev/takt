import uuid
from datetime import UTC, datetime

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.task import (
    ActivityLog,
    ChecklistItem,
    Comment,
    Label,
    Task,
    TaskAssignee,
    TaskLabel,
    TaskPriority,
)
from app.models.team import TaskStatus
from app.models.user import User


async def get_status(db: AsyncSession, status_id: uuid.UUID) -> TaskStatus | None:
    return await db.get(TaskStatus, status_id)


async def log_activity(
    db: AsyncSession,
    task_id: uuid.UUID,
    user_id: uuid.UUID,
    action: str,
    field: str | None = None,
    old_value: str | None = None,
    new_value: str | None = None,
) -> None:
    db.add(
        ActivityLog(
            task_id=task_id,
            user_id=user_id,
            action=action,
            field=field,
            old_value=old_value,
            new_value=new_value,
            created_at=datetime.now(UTC),
        )
    )


async def apply_status_change(db: AsyncSession, task: Task, new_status: TaskStatus) -> bool:
    """Apply status. Returns True if task newly entered an is_done column."""
    was_done = bool(task.status.is_done) if task.status is not None else False
    task.status_id = new_status.id
    # Keep loaded relationship in sync — otherwise serializers return a stale nested status
    # until the identity map is expired/refetched.
    task.status = new_status
    if new_status.is_done:
        task.closed_at = datetime.now(UTC)
    else:
        task.closed_at = None
    return bool(new_status.is_done) and not was_done


def task_query_base():
    return select(Task).options(
        selectinload(Task.status),
        selectinload(Task.author),
        selectinload(Task.assignees).selectinload(TaskAssignee.user),
        selectinload(Task.labels).selectinload(TaskLabel.label),
        selectinload(Task.checklist_items),
    ).where(Task.deleted_at.is_(None))


async def list_tasks(
    db: AsyncSession,
    *,
    search: str | None = None,
    status_id: uuid.UUID | None = None,
    priority: TaskPriority | None = None,
    assignee_id: uuid.UUID | None = None,
    label_id: uuid.UUID | None = None,
    due_before: datetime | None = None,
    due_after: datetime | None = None,
    mine_user_id: uuid.UUID | None = None,
    project_id: uuid.UUID | None = None,
    parent_id: uuid.UUID | None = None,
    include_archived: bool = False,
    roots_only: bool = True,
    page: int = 1,
    page_size: int = 500,
) -> tuple[list[Task], int]:
    q = task_query_base()
    if not include_archived:
        q = q.where(Task.archived_at.is_(None))
    if roots_only and parent_id is None:
        q = q.where(Task.parent_id.is_(None))
    if parent_id is not None:
        q = q.where(Task.parent_id == parent_id)
    if project_id:
        q = q.where(Task.project_id == project_id)
    if search:
        like = f"%{search}%"
        q = q.where(or_(Task.title.ilike(like), Task.description.ilike(like)))
    if status_id:
        q = q.where(Task.status_id == status_id)
    if priority:
        q = q.where(Task.priority == priority)
    if due_before:
        q = q.where(Task.due_date <= due_before)
    if due_after:
        q = q.where(Task.due_date >= due_after)
    if assignee_id:
        q = q.join(TaskAssignee).where(TaskAssignee.user_id == assignee_id)
    if label_id:
        q = q.join(TaskLabel).where(TaskLabel.label_id == label_id)
    if mine_user_id:
        q = q.join(TaskAssignee, isouter=True).where(
            or_(Task.author_id == mine_user_id, TaskAssignee.user_id == mine_user_id)
        )
    count_q = select(func.count()).select_from(q.subquery())
    total = await db.scalar(count_q) or 0
    q = q.order_by(Task.status_id, Task.position).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(q)
    return list(result.scalars().unique().all()), total


async def get_task(db: AsyncSession, task_id: uuid.UUID) -> Task | None:
    # populate_existing: after delete/replace of assignees/labels in the same session,
    # selectinload would otherwise reuse a stale empty collection from the identity map.
    q = (
        task_query_base()
        .where(Task.id == task_id)
        .execution_options(populate_existing=True)
    )
    result = await db.execute(q)
    return result.scalar_one_or_none()


async def comment_counts_for(db: AsyncSession, task_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    if not task_ids:
        return {}
    rows = await db.execute(
        select(Comment.task_id, func.count())
        .where(Comment.task_id.in_(task_ids))
        .group_by(Comment.task_id)
    )
    return {tid: int(cnt) for tid, cnt in rows.all()}


async def subtask_stats_for(
    db: AsyncSession, task_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[int, int]]:
    """Return {parent_id: (total, done)} for open (non-deleted) children."""
    if not task_ids:
        return {}
    rows = await db.execute(
        select(
            Task.parent_id,
            func.count(),
            func.count().filter(Task.closed_at.isnot(None)),
        )
        .where(Task.parent_id.in_(task_ids), Task.deleted_at.is_(None))
        .group_by(Task.parent_id)
    )
    return {pid: (int(total), int(done or 0)) for pid, total, done in rows.all()}


async def next_position(db: AsyncSession, status_id: uuid.UUID) -> float:
    max_pos = await db.scalar(
        select(func.max(Task.position)).where(
            Task.status_id == status_id, Task.deleted_at.is_(None)
        )
    )
    return (max_pos or 0) + 1024.0


async def get_or_create_label(db: AsyncSession, name: str, color: str = "#22c55e") -> Label:
    result = await db.execute(select(Label).where(Label.name == name))
    label = result.scalar_one_or_none()
    if label:
        return label
    label = Label(name=name, color=color)
    db.add(label)
    await db.flush()
    return label


def can_delete_task(user: User, task: Task) -> bool:
    """Only the task author may delete — no owner/admin override."""
    return task.author_id == user.id


async def soft_delete_task(db: AsyncSession, task: Task) -> None:
    task.deleted_at = datetime.now(UTC)
