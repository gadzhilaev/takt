"""project invites

Revision ID: 003
Revises: 002
Create Date: 2026-10-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    invitestatus = postgresql.ENUM(
        "pending",
        "accepted",
        "declined",
        "cancelled",
        name="projectinvitestatus",
        create_type=True,
    )
    invitestatus.create(op.get_bind(), checkfirst=True)
    op.create_table(
        "project_invites",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "project_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column(
            "invited_by_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "invitee_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("token", sa.String(64), nullable=False, unique=True),
        sa.Column(
            "status",
            invitestatus,
            nullable=False,
            server_default="pending",
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_project_invites_project_id", "project_invites", ["project_id"])
    op.create_index("ix_project_invites_email", "project_invites", ["email"])


def downgrade() -> None:
    op.drop_index("ix_project_invites_email", table_name="project_invites")
    op.drop_index("ix_project_invites_project_id", table_name="project_invites")
    op.drop_table("project_invites")
    op.execute("DROP TYPE IF EXISTS projectinvitestatus")
