"""OAuth login state: return_path for invite/next after callback.

Revision ID: 015
Revises: 014
Create Date: 2026-10-31
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "015"
down_revision: Union[str, None] = "014"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "oauth_login_states",
        sa.Column("return_path", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("oauth_login_states", "return_path")
