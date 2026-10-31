"""allow open project invite links (nullable email)

Revision ID: 014
Revises: 013
Create Date: 2026-10-31
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "014"
down_revision: Union[str, None] = "013"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "project_invites",
        "email",
        existing_type=sa.String(length=320),
        nullable=True,
    )


def downgrade() -> None:
    op.execute("UPDATE project_invites SET email = '' WHERE email IS NULL")
    op.alter_column(
        "project_invites",
        "email",
        existing_type=sa.String(length=320),
        nullable=False,
    )
