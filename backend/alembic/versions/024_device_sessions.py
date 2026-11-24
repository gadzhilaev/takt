"""Track login sessions across refresh token renewals.

Revision ID: 024
Revises: 023
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "024"
down_revision: Union[str, None] = "023"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("refresh_tokens", sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("refresh_tokens", sa.Column("user_agent", sa.String(length=512), nullable=True))
    op.add_column("refresh_tokens", sa.Column("platform", sa.String(length=32), nullable=True))
    # Existing refresh rows each become their own session; new rows keep the ID
    # through subsequent refresh renewals.
    op.execute(sa.text("UPDATE refresh_tokens SET session_id = id WHERE session_id IS NULL"))
    op.alter_column("refresh_tokens", "session_id", nullable=False)
    op.create_index("ix_refresh_tokens_session_id", "refresh_tokens", ["session_id"])


def downgrade() -> None:
    op.drop_index("ix_refresh_tokens_session_id", table_name="refresh_tokens")
    op.drop_column("refresh_tokens", "platform")
    op.drop_column("refresh_tokens", "user_agent")
    op.drop_column("refresh_tokens", "session_id")
