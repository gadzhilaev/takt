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
    cols = {c["name"] for c in sa.inspect(op.get_bind()).get_columns("users")}
    if "is_demo" not in cols:
        op.add_column(
            "users",
            sa.Column("is_demo", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        )
    indexes = {i["name"] for i in sa.inspect(op.get_bind()).get_indexes("users") if i.get("name")}
    if "ix_users_is_demo" not in indexes:
        op.create_index("ix_users_is_demo", "users", ["is_demo"])


def downgrade() -> None:
    op.drop_index("ix_users_is_demo", table_name="users")
    op.drop_column("users", "is_demo")
