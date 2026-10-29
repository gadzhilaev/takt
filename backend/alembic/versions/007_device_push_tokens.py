"""FCM/APNs device tokens for mobile push (separate from Web Push)

Revision ID: 007
Revises: 006
Create Date: 2026-10-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "007"
down_revision: Union[str, None] = "006"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "device_push_tokens" not in tables:
        op.create_table(
            "device_push_tokens",
            sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
            sa.Column(
                "user_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("token", sa.Text(), nullable=False),
            sa.Column("platform", sa.String(20), nullable=False),
            sa.Column("app_version", sa.String(40), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("token", name="uq_device_push_token"),
        )

    indexes = {
        i["name"]
        for i in sa.inspect(op.get_bind()).get_indexes("device_push_tokens")
        if i.get("name")
    }
    if "ix_device_push_tokens_user_id" not in indexes:
        op.create_index("ix_device_push_tokens_user_id", "device_push_tokens", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_device_push_tokens_user_id", table_name="device_push_tokens")
    op.drop_table("device_push_tokens")
