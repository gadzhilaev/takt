"""Remap legacy default status colors to new Kanban presets.

Only updates known old default hex values — custom column colors are left intact.

Revision ID: 008
Revises: 007
Create Date: 2026-10-28
"""

from typing import Sequence, Union

from alembic import op
from sqlalchemy import text

revision: str = "008"
down_revision: Union[str, None] = "007"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None

# Old defaults → new accents (case handled in SQL via lower())
_LEGACY_MAP = {
    "#94a3b8": "#7892B2",  # К выполнению
    "#315f72": "#4B8CAF",  # В работе
    "#5c7380": "#9774BD",  # На проверке
    "#2f6b4f": "#4B9873",  # Готово
}


def upgrade() -> None:
    conn = op.get_bind()
    for old, new in _LEGACY_MAP.items():
        conn.execute(
            text(
                "UPDATE statuses SET color = :new "
                "WHERE lower(color) = :old"
            ),
            {"old": old, "new": new},
        )


def downgrade() -> None:
    conn = op.get_bind()
    reverse = {v.lower(): k for k, v in _LEGACY_MAP.items()}
    # Reverse only exact new defaults (may also hit intentional new colors — acceptable for downgrade)
    for new_lower, old in reverse.items():
        conn.execute(
            text(
                "UPDATE statuses SET color = :old "
                "WHERE lower(color) = :new"
            ),
            {"new": new_lower, "old": old},
        )
