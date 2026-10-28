"""Remap previous Kanban default accents to stronger v2 presets.

Only updates known prior default hex values — custom column colors stay intact.

Revision ID: 009
Revises: 008
Create Date: 2026-10-28
"""

from typing import Sequence, Union

from alembic import op
from sqlalchemy import text

revision: str = "009"
down_revision: Union[str, None] = "008"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None

# Prior standard accents (incl. pre-008 and 008 targets) → v2 accents
_LEGACY_MAP = {
    "#94a3b8": "#607FA4",
    "#7892b2": "#607FA4",
    "#315f72": "#347FA4",
    "#4b8caf": "#347FA4",
    "#5c7380": "#9062B8",
    "#9774bd": "#9062B8",
    "#2f6b4f": "#398A62",
    "#4b9873": "#398A62",
}


def upgrade() -> None:
    conn = op.get_bind()
    for old, new in _LEGACY_MAP.items():
        conn.execute(
            text("UPDATE statuses SET color = :new WHERE lower(color) = :old"),
            {"old": old, "new": new},
        )


def downgrade() -> None:
    conn = op.get_bind()
    # Downgrade to 008-era accents (not the oldest slate hexes)
    reverse = {
        "#607fa4": "#7892B2",
        "#347fa4": "#4B8CAF",
        "#9062b8": "#9774BD",
        "#398a62": "#4B9873",
    }
    for new_lower, old in reverse.items():
        conn.execute(
            text("UPDATE statuses SET color = :old WHERE lower(color) = :new"),
            {"new": new_lower, "old": old},
        )
