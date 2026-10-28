"""initial schema

Revision ID: 001
Revises:
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    from app.models.base import Base

    bind = op.get_bind()
    Base.metadata.create_all(bind)


def downgrade() -> None:
    from app.models.base import Base

    bind = op.get_bind()
    Base.metadata.drop_all(bind)
