"""projects, notifications, task/project links

Revision ID: 002
Revises: 001
Create Date: 2026-10-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "projects",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("color", sa.String(7), nullable=False, server_default="#4f46e5"),
        sa.Column("icon", sa.String(40), nullable=False, server_default="folder"),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "project_members",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "role",
            sa.Enum("admin", "member", "viewer", name="projectmemberrole"),
            nullable=False,
            server_default="member",
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("project_id", "user_id", name="uq_project_member"),
    )
    op.create_index("ix_project_members_project_id", "project_members", ["project_id"])
    op.create_index("ix_project_members_user_id", "project_members", ["user_id"])

    op.create_table(
        "notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("task_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tasks.id", ondelete="CASCADE"), nullable=True),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=True),
        sa.Column("kind", sa.String(50), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_task_id", "notifications", ["task_id"])
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"])

    op.add_column("statuses", sa.Column("project_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key(
        "fk_statuses_project_id",
        "statuses",
        "projects",
        ["project_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index("ix_statuses_project_id", "statuses", ["project_id"])

    op.add_column("tasks", sa.Column("project_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("tasks", sa.Column("parent_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("tasks", sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True))
    op.create_foreign_key(
        "fk_tasks_project_id",
        "tasks",
        "projects",
        ["project_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_tasks_parent_id",
        "tasks",
        "tasks",
        ["parent_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_tasks_project_id", "tasks", ["project_id"])
    op.create_index("ix_tasks_parent_id", "tasks", ["parent_id"])

    # Data migration: default project + backfill
    op.execute(
        """
        INSERT INTO projects (id, name, description, color, icon, is_default, is_archived, created_at, updated_at)
        SELECT gen_random_uuid(), 'Общее', 'Задачи без отдельного проекта', '#4f46e5', 'inbox', true, false, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM projects WHERE is_default = true)
        """
    )
    op.execute(
        """
        UPDATE statuses SET project_id = (SELECT id FROM projects WHERE is_default = true LIMIT 1)
        WHERE project_id IS NULL
        """
    )
    op.execute(
        """
        UPDATE tasks SET project_id = (SELECT id FROM projects WHERE is_default = true LIMIT 1)
        WHERE project_id IS NULL
        """
    )
    op.execute(
        """
        INSERT INTO project_members (id, project_id, user_id, role, created_at, updated_at)
        SELECT gen_random_uuid(), p.id, u.id,
               CASE WHEN u.role::text = 'admin' THEN 'admin'::projectmemberrole ELSE 'member'::projectmemberrole END,
               NOW(), NOW()
        FROM users u
        CROSS JOIN projects p
        WHERE p.is_default = true
          AND NOT EXISTS (
            SELECT 1 FROM project_members pm WHERE pm.project_id = p.id AND pm.user_id = u.id
          )
        """
    )


def downgrade() -> None:
    op.drop_constraint("fk_tasks_parent_id", "tasks", type_="foreignkey")
    op.drop_constraint("fk_tasks_project_id", "tasks", type_="foreignkey")
    op.drop_index("ix_tasks_parent_id", table_name="tasks")
    op.drop_index("ix_tasks_project_id", table_name="tasks")
    op.drop_column("tasks", "archived_at")
    op.drop_column("tasks", "parent_id")
    op.drop_column("tasks", "project_id")

    op.drop_constraint("fk_statuses_project_id", "statuses", type_="foreignkey")
    op.drop_index("ix_statuses_project_id", table_name="statuses")
    op.drop_column("statuses", "project_id")

    op.drop_table("notifications")
    op.drop_table("project_members")
    op.drop_table("projects")
    op.execute("DROP TYPE IF EXISTS projectmemberrole")
