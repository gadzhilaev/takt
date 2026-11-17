"""Digest goes to every project member by default (anyone can unsubscribe).

Revision ID: 023
Revises: 022
Create Date: 2026-11-17

Data: turns the subscription on for all current members (before, only admins received
the digest and nobody could have opted out yet, so nothing is lost). Downgrade only
restores the old column default; per-member values are kept.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "023"
down_revision: Union[str, None] = "022"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("project_members", "digest_subscribed", server_default=sa.text("true"))
    op.execute(sa.text("UPDATE project_members SET digest_subscribed = true"))


def downgrade() -> None:
    op.alter_column("project_members", "digest_subscribed", server_default=sa.text("false"))
