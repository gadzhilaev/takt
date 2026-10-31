import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ProjectInviteStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"
    cancelled = "cancelled"


class ProjectInvite(Base):
    __tablename__ = "project_invites"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), index=True
    )
    # None = открытая ссылка-приглашение (любой вошедший пользователь).
    email: Mapped[str | None] = mapped_column(String(320), nullable=True, index=True)
    invited_by_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE")
    )
    invitee_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    token: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    status: Mapped[ProjectInviteStatus] = mapped_column(
        Enum(ProjectInviteStatus), default=ProjectInviteStatus.pending, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
