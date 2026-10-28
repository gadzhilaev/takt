"""user is_demo flag for demo-only profiles

Revision ID: 006
Revises: 005
Create Date: 2026-10-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("is_demo", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.create_index("ix_users_is_demo", "users", ["is_demo"])


def downgrade() -> None:
    op.drop_index("ix_users_is_demo", table_name="users")
    op.drop_column("users", "is_demo")
