"""Rhythm: daily check-in per user and project, with one answer row per task."""

import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, utc_now


class CheckinStatus(enum.StrEnum):
    pending = "pending"
    answered = "answered"
    skipped = "skipped"


class CheckinAnswer(enum.StrEnum):
    done = "done"
    in_progress = "in_progress"
    blocked = "blocked"


class RhythmCheckin(Base):
    __tablename__ = "rhythm_checkins"
    __table_args__ = (
        # Strictly one check-in per person, project and local day (idempotency).
        UniqueConstraint("user_id", "project_id", "date", name="uq_rhythm_checkin_day"),
        Index("ix_rhythm_checkins_user_date", "user_id", "date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("projects.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    # Local calendar day in the project's rhythm timezone.
    date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), default=CheckinStatus.pending.value, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # sha256 of a one-time token sent in the push payload (answer straight from a notification).
    push_token_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    items: Mapped[list["RhythmCheckinItem"]] = relationship(
        back_populates="checkin",
        cascade="all, delete-orphan",
        order_by="RhythmCheckinItem.position",
    )


class RhythmCheckinItem(Base):
    __tablename__ = "rhythm_checkin_items"
    __table_args__ = (UniqueConstraint("checkin_id", "task_id", name="uq_rhythm_item_task"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    checkin_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("rhythm_checkins.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    task_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tasks.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    answer: Mapped[str | None] = mapped_column(String(16), nullable=True)
    reason: Mapped[str | None] = mapped_column(String(280), nullable=True)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    checkin: Mapped[RhythmCheckin] = relationship(back_populates="items")
