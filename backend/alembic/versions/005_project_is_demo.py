"""project is_demo flag for workspace isolation

Revision ID: 005
Revises: 004
Create Date: 2026-10-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "005"
down_revision: Union[str, None] = "004"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "projects",
        sa.Column("is_demo", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.create_index("ix_projects_is_demo", "projects", ["is_demo"])


def downgrade() -> None:
    op.drop_index("ix_projects_is_demo", table_name="projects")
    op.drop_column("projects", "is_demo")
