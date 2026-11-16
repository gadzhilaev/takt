"""Digest («Сводка»): project schedule, member subscription, delivery log.

Revision ID: 022
Revises: 021
Create Date: 2026-11-17

Safe: only adds columns/tables (existing projects: weekly digest on, daily off).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "022"
down_revision: Union[str, None] = "021"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "projects",
        sa.Column("digest_daily", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "projects",
        sa.Column("digest_weekly", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.add_column(
        "projects",
        sa.Column("digest_time", sa.Time(), nullable=False, server_default=sa.text("'18:00'")),
    )
    op.add_column(
        "project_members",
        sa.Column(
            "digest_subscribed", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
    )
    op.create_table(
        "digest_deliveries",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "project_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "recipient_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("period", sa.String(8), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("channels", sa.String(64), nullable=True),
        sa.UniqueConstraint(
            "project_id", "period", "period_end", "recipient_id", name="uq_digest_delivery"
        ),
    )
    op.create_index("ix_digest_deliveries_project_id", "digest_deliveries", ["project_id"])
    op.create_index("ix_digest_deliveries_recipient_id", "digest_deliveries", ["recipient_id"])


def downgrade() -> None:
    op.drop_index("ix_digest_deliveries_recipient_id", table_name="digest_deliveries")
    op.drop_index("ix_digest_deliveries_project_id", table_name="digest_deliveries")
    op.drop_table("digest_deliveries")
    op.drop_column("project_members", "digest_subscribed")
    op.drop_column("projects", "digest_time")
    op.drop_column("projects", "digest_weekly")
    op.drop_column("projects", "digest_daily")
