"""Rewrite legacy long assignment/completion notification titles to short card copy.

Revision ID: 018
Revises: 017
Create Date: 2026-11-05
"""

from __future__ import annotations

import re
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "018"
down_revision: Union[str, None] = "017"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_ASSIGN = re.compile(
    r"^(.+?)\s+(назначил[аи]?)\b.*?[«\"](.+?)[»\"]\.?\s*$",
    re.IGNORECASE | re.DOTALL,
)
_COMPLETE = re.compile(
    r"^(.+?)\s+(завершил[аи]?)\b.*?[«\"](.+?)[»\"]\.?\s*$",
    re.IGNORECASE | re.DOTALL,
)


def _project_line(name: str | None) -> str | None:
    if not name or not str(name).strip():
        return None
    return f"Проект {str(name).strip()}"


def upgrade() -> None:
    conn = op.get_bind()
    rows = conn.execute(
        sa.text(
            """
            SELECT n.id, n.kind, n.title, n.body, p.name AS project_name
            FROM notifications n
            LEFT JOIN projects p ON p.id = n.project_id
            WHERE n.kind IN ('task_assigned', 'assignee_added', 'task_completed')
            """
        )
    ).mappings().all()

    for row in rows:
        title = (row["title"] or "").strip()
        kind = row["kind"]
        project = _project_line(row["project_name"])
        new_title: str | None = None
        new_body: str | None = None

        if kind in ("task_assigned", "assignee_added"):
            m = _ASSIGN.match(title)
            if m:
                actor, verb, task = m.group(1).strip(), m.group(2).lower(), m.group(3).strip()
                new_title = task[:255]
                line = f"{actor} {verb} вам задачу"
                new_body = f"{line}\n{project}" if project else line
        elif kind == "task_completed":
            m = _COMPLETE.match(title)
            if m:
                actor, verb, task = m.group(1).strip(), m.group(2).lower(), m.group(3).strip()
                new_title = task[:255]
                line = f"{actor} {verb} задачу"
                new_body = f"{line}\n{project}" if project else line

        # New-format title already short, but body still has useless link hint.
        if new_title is None:
            body = (row["body"] or "").strip()
            if body and "открывается по ссылке" in body.lower() and project:
                if "назначил" not in body.lower() and "завершил" not in body.lower():
                    conn.execute(
                        sa.text("UPDATE notifications SET body = :body WHERE id = :id"),
                        {"body": project, "id": row["id"]},
                    )
            continue

        conn.execute(
            sa.text("UPDATE notifications SET title = :title, body = :body WHERE id = :id"),
            {"title": new_title, "body": new_body, "id": row["id"]},
        )


def downgrade() -> None:
    # Irreversible data rewrite.
    pass
