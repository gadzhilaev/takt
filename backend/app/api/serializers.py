from app.models.task import ChecklistItem, Task, TaskAssignee, TaskLabel
from app.models.user import User
from app.schemas.task import ChecklistItemOut, LabelOut, StatusOut, TaskOut, UserBrief


def avatar_url(user: User) -> str | None:
    if user.avatar_path:
        return f"/api/v1/files/avatars/{user.id}"
    return None


def user_brief(user: User) -> UserBrief:
    return UserBrief(id=str(user.id), name=user.name, avatar_url=avatar_url(user))


def task_to_out(task: Task) -> TaskOut:
    assignees = []
    for a in task.assignees or []:
        if a.user:
            assignees.append(user_brief(a.user))
    labels = []
    for tl in task.labels or []:
        if tl.label:
            labels.append(
                LabelOut(id=str(tl.label.id), name=tl.label.name, color=tl.label.color)
            )
    items: list[ChecklistItem] = list(task.checklist_items or [])
    return TaskOut(
        id=str(task.id),
        title=task.title,
        description=task.description,
        status_id=str(task.status_id),
        status=StatusOut.model_validate(task.status) if task.status else None,
        priority=task.priority,
        author_id=str(task.author_id),
        author=user_brief(task.author) if task.author else None,
        due_date=task.due_date,
        closed_at=task.closed_at,
        position=task.position,
        created_at=task.created_at,
        updated_at=task.updated_at,
        assignees=assignees,
        labels=labels,
        checklist_items=[ChecklistItemOut.model_validate(i) for i in items],
        checklist_done=sum(1 for i in items if i.is_done),
        checklist_total=len(items),
    )
