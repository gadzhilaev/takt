"""add reset_password to emailcodepurpose

Revision ID: 013
Revises: 012
Create Date: 2026-10-30
"""

from typing import Sequence, Union

from alembic import op

revision: str = "013"
down_revision: Union[str, None] = "012"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE emailcodepurpose ADD VALUE IF NOT EXISTS 'reset_password'")


def downgrade() -> None:
    # PostgreSQL cannot easily drop enum values; leave as no-op.
    pass
