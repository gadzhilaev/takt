"""Task status_entered_at for time-in-column display.

Revision ID: 016
Revises: 015
Create Date: 2026-11-03
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "016"
down_revision: Union[str, None] = "015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("status_entered_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.execute(
        sa.text(
            "UPDATE tasks SET status_entered_at = COALESCE(updated_at, created_at, NOW()) "
            "WHERE status_entered_at IS NULL"
        )
    )
    op.alter_column("tasks", "status_entered_at", nullable=False)
    op.create_index("ix_tasks_status_entered_at", "tasks", ["status_entered_at"])


def downgrade() -> None:
    op.drop_index("ix_tasks_status_entered_at", table_name="tasks")
    op.drop_column("tasks", "status_entered_at")
