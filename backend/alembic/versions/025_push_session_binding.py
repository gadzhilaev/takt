"""Associate push registrations with the device session that owns them."""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "025"
down_revision: str | None = "024"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    for table in ("push_subscriptions", "device_push_tokens"):
        op.add_column(
            table,
            sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=True),
        )
        op.create_index(f"ix_{table}_session_id", table, ["session_id"])


def downgrade() -> None:
    for table in ("device_push_tokens", "push_subscriptions"):
        op.drop_index(f"ix_{table}_session_id", table_name=table)
        op.drop_column(table, "session_id")
