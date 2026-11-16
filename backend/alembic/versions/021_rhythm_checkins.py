"""Rhythm: project check-in settings, daily check-ins, «blocked» flag on tasks.

Revision ID: 021
Revises: 020
Create Date: 2026-11-16

Safe: only adds columns/tables. Existing projects get rhythm_enabled=false
(new projects are created with rhythm on by project_service).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "021"
down_revision: Union[str, None] = "020"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "projects",
        sa.Column("rhythm_enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "projects",
        sa.Column("rhythm_time", sa.Time(), nullable=False, server_default=sa.text("'10:00'")),
    )
    op.add_column(
        "projects",
        sa.Column(
            "rhythm_timezone",
            sa.String(64),
            nullable=False,
            server_default=sa.text("'Europe/Moscow'"),
        ),
    )
    op.add_column(
        "projects",
        sa.Column(
            "rhythm_days",
            postgresql.ARRAY(sa.Integer()),
            nullable=False,
            server_default=sa.text("'{1,2,3,4,5}'"),
        ),
    )

    op.add_column("tasks", sa.Column("blocked_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("tasks", sa.Column("blocked_reason", sa.String(280), nullable=True))
    op.add_column(
        "tasks",
        sa.Column(
            "blocked_by_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    op.create_table(
        "rhythm_checkins",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "project_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("push_token_hash", sa.String(64), nullable=True),
        sa.UniqueConstraint("user_id", "project_id", "date", name="uq_rhythm_checkin_day"),
    )
    op.create_index("ix_rhythm_checkins_user_date", "rhythm_checkins", ["user_id", "date"])
    op.create_index("ix_rhythm_checkins_project_id", "rhythm_checkins", ["project_id"])

    op.create_table(
        "rhythm_checkin_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "checkin_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("rhythm_checkins.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "task_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tasks.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("answer", sa.String(16), nullable=True),
        sa.Column("reason", sa.String(280), nullable=True),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("checkin_id", "task_id", name="uq_rhythm_item_task"),
    )
    op.create_index("ix_rhythm_checkin_items_checkin_id", "rhythm_checkin_items", ["checkin_id"])
    op.create_index("ix_rhythm_checkin_items_task_id", "rhythm_checkin_items", ["task_id"])


def downgrade() -> None:
    op.drop_index("ix_rhythm_checkin_items_task_id", table_name="rhythm_checkin_items")
    op.drop_index("ix_rhythm_checkin_items_checkin_id", table_name="rhythm_checkin_items")
    op.drop_table("rhythm_checkin_items")
    op.drop_index("ix_rhythm_checkins_project_id", table_name="rhythm_checkins")
    op.drop_index("ix_rhythm_checkins_user_date", table_name="rhythm_checkins")
    op.drop_table("rhythm_checkins")
    op.drop_column("tasks", "blocked_by_id")
    op.drop_column("tasks", "blocked_reason")
    op.drop_column("tasks", "blocked_at")
    op.drop_column("projects", "rhythm_days")
    op.drop_column("projects", "rhythm_timezone")
    op.drop_column("projects", "rhythm_time")
    op.drop_column("projects", "rhythm_enabled")
