from app.models.task import Attachment, ChecklistItem, Task, TaskAssignee, TaskLabel
from app.models.user import User
from app.schemas.task import AttachmentOut, ChecklistItemOut, LabelOut, StatusOut, TaskOut, UserBrief
from app.services.attachment_service import is_image_content_type


def avatar_url(user: User) -> str | None:
    if user.avatar_path:
        return f"/api/v1/files/avatars/{user.id}"
    return None


def user_brief(user: User) -> UserBrief:
    return UserBrief(id=str(user.id), name=user.name, avatar_url=avatar_url(user))


def status_to_out(status) -> StatusOut:
    return StatusOut(
        id=str(status.id),
        name=status.name,
        color=status.color,
        position=float(status.position),
        is_done=bool(status.is_done),
        project_id=str(status.project_id) if getattr(status, "project_id", None) else None,
    )


def checklist_to_out(item: ChecklistItem) -> ChecklistItemOut:
    return ChecklistItemOut(
        id=str(item.id),
        title=item.title,
        is_done=bool(item.is_done),
        position=float(item.position),
    )


def attachment_to_out(att: Attachment) -> AttachmentOut:
    aid = str(att.id)
    is_image = is_image_content_type(att.content_type)
    return AttachmentOut(
        id=aid,
        filename=att.filename,
        content_type=att.content_type,
        size_bytes=att.size_bytes,
        is_image=is_image,
        url=f"/api/v1/files/attachments/{aid}",
        preview_url=(
            f"/api/v1/files/attachments/{aid}/preview"
            if att.preview_stored_name or is_image
            else None
        ),
        created_at=att.created_at,
    )


def task_to_out(task: Task, *, comment_count: int = 0, subtask_total: int = 0, subtask_done: int = 0) -> TaskOut:
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
    attachments = [attachment_to_out(a) for a in (task.attachments or [])]
    return TaskOut(
        id=str(task.id),
        project_id=str(task.project_id) if task.project_id else None,
        parent_id=str(task.parent_id) if task.parent_id else None,
        title=task.title,
        description=task.description,
        status_id=str(task.status_id),
        status=status_to_out(task.status) if task.status else None,
        priority=task.priority,
        author_id=str(task.author_id),
        author=user_brief(task.author) if task.author else None,
        due_date=task.due_date,
        closed_at=task.closed_at,
        status_entered_at=getattr(task, "status_entered_at", None) or task.updated_at or task.created_at,
        archived_at=task.archived_at,
        position=task.position,
        created_at=task.created_at,
        updated_at=task.updated_at,
        assignees=assignees,
        labels=labels,
        checklist_items=[checklist_to_out(i) for i in items],
        checklist_done=sum(1 for i in items if i.is_done),
        checklist_total=len(items),
        comment_count=comment_count,
        subtask_total=subtask_total,
        subtask_done=subtask_done,
        attachments=attachments,
    )
