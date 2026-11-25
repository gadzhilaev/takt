"""Add OAuth authorization storage for ChatGPT MCP clients."""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "026"
down_revision: str | None = "025"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "mcp_oauth_clients",
        sa.Column("client_id", sa.String(length=96), primary_key=True),
        sa.Column("client_name", sa.String(length=200), nullable=False),
        sa.Column("redirect_uris", sa.JSON(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_table(
        "mcp_authorization_codes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "client_id",
            sa.String(length=96),
            sa.ForeignKey("mcp_oauth_clients.client_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("redirect_uri", sa.Text(), nullable=False),
        sa.Column("code_challenge", sa.String(length=128), nullable=False),
        sa.Column("resource", sa.Text(), nullable=False),
        sa.Column("scope", sa.String(length=200), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_mcp_authorization_codes_code_hash",
        "mcp_authorization_codes",
        ["code_hash"],
        unique=True,
    )
    op.create_index(
        "ix_mcp_authorization_codes_client_id", "mcp_authorization_codes", ["client_id"]
    )
    op.create_index(
        "ix_mcp_authorization_codes_user_id", "mcp_authorization_codes", ["user_id"]
    )
    op.create_table(
        "mcp_refresh_grants",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "client_id",
            sa.String(length=96),
            sa.ForeignKey("mcp_oauth_clients.client_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("resource", sa.Text(), nullable=False),
        sa.Column("scope", sa.String(length=200), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_mcp_refresh_grants_token_hash",
        "mcp_refresh_grants",
        ["token_hash"],
        unique=True,
    )
    op.create_index("ix_mcp_refresh_grants_client_id", "mcp_refresh_grants", ["client_id"])
    op.create_index("ix_mcp_refresh_grants_user_id", "mcp_refresh_grants", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_mcp_refresh_grants_user_id", table_name="mcp_refresh_grants")
    op.drop_index("ix_mcp_refresh_grants_client_id", table_name="mcp_refresh_grants")
    op.drop_index("ix_mcp_refresh_grants_token_hash", table_name="mcp_refresh_grants")
    op.drop_table("mcp_refresh_grants")
    op.drop_index("ix_mcp_authorization_codes_user_id", table_name="mcp_authorization_codes")
    op.drop_index("ix_mcp_authorization_codes_client_id", table_name="mcp_authorization_codes")
    op.drop_index("ix_mcp_authorization_codes_code_hash", table_name="mcp_authorization_codes")
    op.drop_table("mcp_authorization_codes")
    op.drop_table("mcp_oauth_clients")
