import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.platform import UserActivityEvent


async def record_activity(
    db: AsyncSession,
    user_id: uuid.UUID,
    event_type: str,
    meta: dict | None = None,
) -> None:
    db.add(
        UserActivityEvent(
            id=uuid.uuid4(),
            user_id=user_id,
            event_type=event_type,
            meta=meta,
            created_at=datetime.now(UTC),
        )
    )
