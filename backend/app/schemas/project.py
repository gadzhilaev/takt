from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.project import ProjectMemberRole


class ProjectMemberOut(BaseModel):
    user_id: str
    role: ProjectMemberRole
    name: str
    email: str
    avatar_url: str | None = None


class ProjectOut(BaseModel):
    id: str
    name: str
    description: str | None
    color: str
    icon: str
    is_default: bool
    is_archived: bool
    is_demo: bool = False
    created_at: datetime
    updated_at: datetime
    members: list[ProjectMemberOut] = []
    progress: dict | None = None


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str | None = None
    color: str = "#4f46e5"
    icon: str = "folder"
    member_ids: list[UUID] = []


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    color: str | None = None
    icon: str | None = None
    is_archived: bool | None = None


class ProjectMemberUpdate(BaseModel):
    user_id: UUID
    role: ProjectMemberRole
