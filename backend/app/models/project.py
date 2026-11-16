import enum
import uuid
from datetime import time

from sqlalchemy import (
    Boolean,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class ProjectMemberRole(str, enum.Enum):
    admin = "admin"
    member = "member"
    viewer = "viewer"


class Project(Base, TimestampMixin):
    __tablename__ = "projects"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    color: Mapped[str] = mapped_column(String(7), default="#4f46e5", nullable=False)
    icon: Mapped[str] = mapped_column(String(40), default="folder", nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_demo: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    # Escalate task priority as due_date approaches (see due_urgency_service).
    auto_urgency_from_due: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Rhythm (daily check-in). Existing projects: off; new projects: on (project_service).
    rhythm_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    rhythm_time: Mapped[time] = mapped_column(Time, default=time(10, 0), nullable=False)
    rhythm_timezone: Mapped[str] = mapped_column(
        String(64), default="Europe/Moscow", nullable=False
    )
    # ISO weekdays: 1 = Monday … 7 = Sunday.
    rhythm_days: Mapped[list[int]] = mapped_column(
        ARRAY(Integer), default=lambda: [1, 2, 3, 4, 5], nullable=False
    )
    # Digest («Сводка»): daily at digest_time, weekly on Friday at digest_time (project tz).
    digest_daily: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    digest_weekly: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    digest_time: Mapped[time] = mapped_column(Time, default=time(18, 0), nullable=False)

    members: Mapped[list["ProjectMember"]] = relationship(
        back_populates="project", cascade="all, delete-orphan"
    )


class ProjectMember(Base, TimestampMixin):
    __tablename__ = "project_members"
    __table_args__ = (UniqueConstraint("project_id", "user_id", name="uq_project_member"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    role: Mapped[ProjectMemberRole] = mapped_column(
        Enum(ProjectMemberRole), default=ProjectMemberRole.member, nullable=False
    )
    # Non-admins may subscribe to the project digest; admins always receive it.
    digest_subscribed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    project: Mapped[Project] = relationship(back_populates="members")
