from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.models.project import ProjectMemberRole


class ProjectMemberOut(BaseModel):
    user_id: str
    role: ProjectMemberRole
    name: str
    email: str
    avatar_url: str | None = None


class RhythmSettingsOut(BaseModel):
    enabled: bool
    time: str  # HH:MM, local
    timezone: str
    days: list[int]  # ISO weekdays 1..7


class DigestSettingsOut(BaseModel):
    daily: bool
    weekly: bool  # Friday
    time: str  # HH:MM, project timezone


class ProjectOut(BaseModel):
    id: str
    name: str
    description: str | None
    color: str
    icon: str
    is_default: bool
    is_archived: bool
    is_demo: bool = False
    auto_urgency_from_due: bool = True
    rhythm: RhythmSettingsOut | None = None
    digest: DigestSettingsOut | None = None
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
    auto_urgency_from_due: bool = True


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    color: str | None = None
    icon: str | None = None
    is_archived: bool | None = None
    auto_urgency_from_due: bool | None = None
    rhythm_enabled: bool | None = None
    rhythm_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    rhythm_timezone: str | None = Field(default=None, max_length=64)
    rhythm_days: list[int] | None = None
    digest_daily: bool | None = None
    digest_weekly: bool | None = None
    digest_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")

    @field_validator("rhythm_days")
    @classmethod
    def _days(cls, v: list[int] | None) -> list[int] | None:
        if v is None:
            return v
        days = sorted(set(v))
        if not days or any(d < 1 or d > 7 for d in days):
            raise ValueError("Выберите хотя бы один день недели")
        return days


class ProjectMemberUpdate(BaseModel):
    user_id: UUID
    role: ProjectMemberRole
