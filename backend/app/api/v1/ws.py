from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.api.deps import ACCESS_COOKIE
from app.core.security import decode_token
from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.services.websocket_hub import ws_manager
from sqlalchemy import select
import uuid

router = APIRouter()


async def _user_from_websocket(websocket: WebSocket) -> User | None:
    token = websocket.cookies.get(ACCESS_COOKIE)
    if not token:
        # Also accept query token for tooling (optional)
        token = websocket.query_params.get("access_token")
    if not token:
        return None
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        return None
    try:
        user_id = uuid.UUID(payload["sub"])
    except (KeyError, ValueError):
        return None
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user or not user.is_active:
            return None
        return user


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    user = await _user_from_websocket(websocket)
    if not user:
        await websocket.close(code=4401)
        return
    await ws_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await ws_manager.disconnect(websocket)
