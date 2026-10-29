"""email verification codes for register / change password

Revision ID: 011
Revises: 010
Create Date: 2026-10-29
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "011"
down_revision: Union[str, None] = "010"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    purpose = postgresql.ENUM(
        "register",
        "change_password",
        name="emailcodepurpose",
        create_type=True,
    )
    purpose.create(op.get_bind(), checkfirst=True)

    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "email_codes" not in tables:
        op.create_table(
            "email_codes",
            sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
            sa.Column("email", sa.String(320), nullable=False),
            sa.Column(
                "purpose",
                postgresql.ENUM(
                    "register",
                    "change_password",
                    name="emailcodepurpose",
                    create_type=False,
                ),
                nullable=False,
            ),
            sa.Column("code_hash", sa.String(128), nullable=False),
            sa.Column("payload_json", sa.Text(), nullable=False, server_default="{}"),
            sa.Column(
                "user_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=True,
            ),
            sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )

    indexes = {
        i["name"] for i in sa.inspect(op.get_bind()).get_indexes("email_codes") if i.get("name")
    }
    if "ix_email_codes_email" not in indexes:
        op.create_index("ix_email_codes_email", "email_codes", ["email"])
    if "ix_email_codes_purpose" not in indexes:
        op.create_index("ix_email_codes_purpose", "email_codes", ["purpose"])
    if "ix_email_codes_user_id" not in indexes:
        op.create_index("ix_email_codes_user_id", "email_codes", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_email_codes_user_id", table_name="email_codes")
    op.drop_index("ix_email_codes_purpose", table_name="email_codes")
    op.drop_index("ix_email_codes_email", table_name="email_codes")
    op.drop_table("email_codes")
    op.execute("DROP TYPE IF EXISTS emailcodepurpose")
