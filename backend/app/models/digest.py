"""Digest deliveries: one row per project + period + recipient (idempotency)."""

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, utc_now


class DigestDelivery(Base):
    __tablename__ = "digest_deliveries"
    __table_args__ = (
        UniqueConstraint(
            "project_id", "period", "period_end", "recipient_id", name="uq_digest_delivery"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("projects.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    recipient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    # "day" | "week"; period_end — last local day of the period (project timezone).
    period: Mapped[str] = mapped_column(String(8), nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
    channels: Mapped[str | None] = mapped_column(String(64), nullable=True)
