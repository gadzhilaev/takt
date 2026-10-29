"""project leave requests

Revision ID: 010
Revises: 009
Create Date: 2026-10-29
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "010"
down_revision: Union[str, None] = "009"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    leavestatus = postgresql.ENUM(
        "pending",
        "approved",
        "rejected",
        "cancelled",
        name="projectleaverequeststatus",
    )
    leavestatus.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "project_leave_requests",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "project_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "status",
            postgresql.ENUM(
                "pending",
                "approved",
                "rejected",
                "cancelled",
                name="projectleaverequeststatus",
                create_type=False,
            ),
            nullable=False,
            server_default="pending",
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_project_leave_requests_project_id", "project_leave_requests", ["project_id"])
    op.create_index("ix_project_leave_requests_user_id", "project_leave_requests", ["user_id"])
    op.create_index(
        "uq_leave_pending_per_user",
        "project_leave_requests",
        ["project_id", "user_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )


def downgrade() -> None:
    op.drop_index("uq_leave_pending_per_user", table_name="project_leave_requests")
    op.drop_index("ix_project_leave_requests_user_id", table_name="project_leave_requests")
    op.drop_index("ix_project_leave_requests_project_id", table_name="project_leave_requests")
    op.drop_table("project_leave_requests")
    op.execute("DROP TYPE IF EXISTS projectleaverequeststatus")
