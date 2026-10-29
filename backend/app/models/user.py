import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class UserRole(str, enum.Enum):
    """Legacy workspace role. Platform privileges use ``platform_role``."""

    admin = "admin"
    member = "member"


class PlatformRole(str, enum.Enum):
    """Global Takt platform roles — independent of project membership roles."""

    none = "none"
    support = "support"
    moderator = "moderator"
    admin = "admin"
    super_admin = "super_admin"


PLATFORM_ROLE_RANK = {
    PlatformRole.none: 0,
    PlatformRole.support: 10,
    PlatformRole.moderator: 20,
    PlatformRole.admin: 30,
    PlatformRole.super_admin: 40,
}


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    avatar_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.member, nullable=False)
    platform_role: Mapped[PlatformRole] = mapped_column(
        Enum(PlatformRole, name="platform_role"),
        default=PlatformRole.none,
        nullable=False,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_demo: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    blocked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    block_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user")
    identities: Mapped[list["UserIdentity"]] = relationship(back_populates="user")
    created_tasks: Mapped[list["Task"]] = relationship(
        back_populates="author", foreign_keys="Task.author_id"
    )
