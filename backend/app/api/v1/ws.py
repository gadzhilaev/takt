import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.api.deps import ACCESS_COOKIE
from app.core.config import get_settings
from app.core.security import decode_token
from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.services.websocket_hub import ws_manager

router = APIRouter()


def _token_from_auth_header(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        return None
    return parts[1].strip()


async def _user_from_websocket(websocket: WebSocket) -> User | None:
    # Prefer Authorization / cookie — JWT in query can leak via logs and Referer.
    token = _token_from_auth_header(websocket.headers.get("authorization"))
    if not token:
        token = websocket.cookies.get(ACCESS_COOKIE)
    if not token and get_settings().ALLOW_WS_QUERY_TOKEN:
        # Last resort — JWT in query can appear in proxy logs; mobile should use Bearer.
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
