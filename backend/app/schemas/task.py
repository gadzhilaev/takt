from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.task import TaskPriority


class StatusOut(BaseModel):
    id: str  # UUID from ORM
    name: str
    color: str
    position: float
    is_done: bool

    model_config = {"from_attributes": True}


class LabelOut(BaseModel):
    id: str
    name: str
    color: str

    model_config = {"from_attributes": True}


class UserBrief(BaseModel):
    id: str
    name: str
    avatar_url: str | None


class ChecklistItemOut(BaseModel):
    id: str
    title: str
    is_done: bool
    position: float

    model_config = {"from_attributes": True}


class TaskOut(BaseModel):
    id: str
    title: str
    description: str | None
    status_id: str
    status: StatusOut | None = None
    priority: TaskPriority
    author_id: str
    author: UserBrief | None = None
    due_date: datetime | None
    closed_at: datetime | None
    position: float
    created_at: datetime
    updated_at: datetime
    assignees: list[UserBrief] = []
    labels: list[LabelOut] = []
    checklist_items: list[ChecklistItemOut] = []
    checklist_done: int = 0
    checklist_total: int = 0


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    status_id: UUID
    priority: TaskPriority = TaskPriority.medium
    description: str | None = None
    due_date: datetime | None = None
    assignee_ids: list[UUID] = []
    label_names: list[str] = []


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=500)
    description: str | None = None
    status_id: UUID | None = None
    priority: TaskPriority | None = None
    due_date: datetime | None = None
    position: float | None = None
    assignee_ids: list[UUID] | None = None
    label_names: list[str] | None = None


class TaskMove(BaseModel):
    status_id: UUID
    position: float


class ChecklistCreate(BaseModel):
    title: str = Field(min_length=1, max_length=500)


class ChecklistUpdate(BaseModel):
    title: str | None = None
    is_done: bool | None = None
    position: float | None = None


class CommentCreate(BaseModel):
    body: str = Field(min_length=1)
    mention_user_ids: list[UUID] = []


class CommentOut(BaseModel):
    id: str
    body: str
    author: UserBrief
    created_at: datetime
    mentions: list[str] = []

    model_config = {"from_attributes": True}


class ActivityOut(BaseModel):
    id: str
    action: str
    field: str | None
    old_value: str | None
    new_value: str | None
    user: UserBrief
    created_at: datetime
