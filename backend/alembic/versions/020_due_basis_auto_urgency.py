"""due_basis_at on tasks + auto_urgency_from_due on projects.

Revision ID: 020
Revises: 019
Create Date: 2026-11-05
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "020"
down_revision: Union[str, None] = "019"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("due_basis_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "projects",
        sa.Column(
            "auto_urgency_from_due",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    # Existing deadlines: window starts at task creation.
    op.execute(
        sa.text(
            "UPDATE tasks SET due_basis_at = COALESCE(created_at, NOW()) "
            "WHERE due_date IS NOT NULL AND due_basis_at IS NULL"
        )
    )


def downgrade() -> None:
    op.drop_column("projects", "auto_urgency_from_due")
    op.drop_column("tasks", "due_basis_at")
