"""Platform admin, OAuth identities, moderation.

Revision ID: 012
Revises: 011
Create Date: 2026-10-29
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "012"
down_revision: Union[str, None] = "011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    platform_role = sa.Enum(
        "none",
        "support",
        "moderator",
        "admin",
        "super_admin",
        name="platform_role",
    )
    oauth_provider = sa.Enum("apple", "vk", "yandex", name="oauth_provider")
    moderation_target = sa.Enum("user", "project", "content", name="moderation_target_type")
    moderation_status = sa.Enum(
        "open",
        "in_review",
        "resolved_warning",
        "resolved_restriction",
        "rejected",
        "appealed",
        "closed",
        name="moderation_report_status",
    )
    bind = op.get_bind()
    platform_role.create(bind, checkfirst=True)
    oauth_provider.create(bind, checkfirst=True)
    moderation_target.create(bind, checkfirst=True)
    moderation_status.create(bind, checkfirst=True)

    # Re-bind enums with create_type=False so create_table does not recreate them.
    platform_role = postgresql.ENUM(
        "none", "support", "moderator", "admin", "super_admin", name="platform_role", create_type=False
    )
    oauth_provider = postgresql.ENUM("apple", "vk", "yandex", name="oauth_provider", create_type=False)
    moderation_target = postgresql.ENUM(
        "user", "project", "content", name="moderation_target_type", create_type=False
    )
    moderation_status = postgresql.ENUM(
        "open",
        "in_review",
        "resolved_warning",
        "resolved_restriction",
        "rejected",
        "appealed",
        "closed",
        name="moderation_report_status",
        create_type=False,
    )

    op.add_column(
        "users",
        sa.Column(
            "platform_role",
            platform_role,
            nullable=False,
            server_default="none",
        ),
    )
    op.add_column("users", sa.Column("blocked_until", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("block_reason", sa.Text(), nullable=True))
    op.alter_column("users", "password_hash", existing_type=sa.String(length=255), nullable=True)
    op.create_index("ix_users_platform_role", "users", ["platform_role"])

    # Legacy UserRole.admin → platform super_admin
    op.execute(
        "UPDATE users SET platform_role = 'super_admin' WHERE role = 'admin' AND platform_role = 'none'"
    )

    op.create_table(
        "user_identities",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("provider", oauth_provider, nullable=False),
        sa.Column("provider_user_id", sa.String(255), nullable=False),
        sa.Column("email", sa.String(320), nullable=True),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("display_name", sa.String(200), nullable=True),
        sa.Column("raw_claims", postgresql.JSONB(), nullable=True),
        sa.Column("linked_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("provider", "provider_user_id", name="uq_identity_provider_uid"),
    )
    op.create_index("ix_user_identities_user_id", "user_identities", ["user_id"])

    op.create_table(
        "oauth_login_states",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("state", sa.String(128), nullable=False),
        sa.Column("provider", oauth_provider, nullable=False),
        sa.Column("code_verifier", sa.String(128), nullable=True),
        sa.Column("nonce", sa.String(128), nullable=True),
        sa.Column("redirect_uri", sa.String(500), nullable=False),
        sa.Column("client_kind", sa.String(32), nullable=False, server_default="web"),
        sa.Column("link_user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_oauth_login_states_state", "oauth_login_states", ["state"], unique=True)

    op.create_table(
        "user_blocks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_by_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("blocked_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("lifted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("lifted_by_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_user_blocks_user_id", "user_blocks", ["user_id"])

    op.create_table(
        "project_restrictions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("created_by_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("lifted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "moderation_reports",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("reporter_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("target_type", moderation_target, nullable=False),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("reason_code", sa.String(64), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", moderation_status, nullable=False, server_default="open"),
        sa.Column("assignee_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("decision_note", sa.Text(), nullable=True),
        sa.Column("decided_by_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_moderation_reports_status", "moderation_reports", ["status"])
    op.create_index("ix_moderation_reports_target_id", "moderation_reports", ["target_id"])

    op.create_table(
        "moderation_actions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("report_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("moderation_reports.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("action", sa.String(64), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_moderation_actions_report_id", "moderation_actions", ["report_id"])

    op.create_table(
        "platform_settings",
        sa.Column("key", sa.String(100), primary_key=True),
        sa.Column("value", postgresql.JSONB(), nullable=False),
        sa.Column("updated_by_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "user_activity_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("meta", postgresql.JSONB(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_user_activity_events_event_type", "user_activity_events", ["event_type"])
    op.create_index("ix_user_activity_events_created_at", "user_activity_events", ["created_at"])
    op.create_index("ix_activity_user_created", "user_activity_events", ["user_id", "created_at"])

    op.create_table(
        "admin_mfa_secrets",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("secret_encrypted", sa.Text(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )


def downgrade() -> None:
    op.drop_table("admin_mfa_secrets")
    op.drop_table("user_activity_events")
    op.drop_table("platform_settings")
    op.drop_table("moderation_actions")
    op.drop_table("moderation_reports")
    op.drop_table("project_restrictions")
    op.drop_table("user_blocks")
    op.drop_table("oauth_login_states")
    op.drop_table("user_identities")
    op.drop_index("ix_users_platform_role", table_name="users")
    op.drop_column("users", "block_reason")
    op.drop_column("users", "blocked_until")
    op.drop_column("users", "platform_role")
    op.alter_column("users", "password_hash", existing_type=sa.String(length=255), nullable=False)
    sa.Enum(name="moderation_report_status").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="moderation_target_type").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="oauth_provider").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="platform_role").drop(op.get_bind(), checkfirst=True)
