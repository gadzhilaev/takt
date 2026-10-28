import uuid

from sqlalchemy import Boolean, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class TeamSettings(Base, TimestampMixin):
    __tablename__ = "team_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    team_name: Mapped[str] = mapped_column(String(200), default="Моя команда", nullable=False)
    logo_path: Mapped[str | None] = mapped_column(String(500), nullable=True)


class TaskStatus(Base, TimestampMixin):
    __tablename__ = "statuses"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    color: Mapped[str] = mapped_column(String(7), default="#6366f1", nullable=False)
    position: Mapped[float] = mapped_column(nullable=False, default=0)
    is_done: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
