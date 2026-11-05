"""Add due_soon_notified_at and overdue_notified_at on tasks.

Revision ID: 019
Revises: 018
Create Date: 2026-11-05
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "019"
down_revision: Union[str, None] = "018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("due_soon_notified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "tasks",
        sa.Column("overdue_notified_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("tasks", "overdue_notified_at")
    op.drop_column("tasks", "due_soon_notified_at")
