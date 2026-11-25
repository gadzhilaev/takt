"""Remote MCP tools for Takt, authenticated with the user's existing access JWT."""

from __future__ import annotations

import json
import uuid
from contextvars import ContextVar
from datetime import datetime
from typing import Any

from jose import JWTError, jwt
from mcp.server.fastmcp import FastMCP
from sqlalchemy import select
from starlette.types import ASGIApp, Receive, Scope, Send

from app.api.serializers import status_to_out
from app.core.config import get_settings
from app.core.security import decode_token
from app.db.session import AsyncSessionLocal
from app.models.team import TaskStatus
from app.models.user import User
from app.schemas.task import (
    ChecklistCreate,
    ChecklistUpdate,
    CommentCreate,
    TaskCreate,
    TaskMove,
    TaskUpdate,
)
from app.services import project_service, task_service

_current_user_id: ContextVar[uuid.UUID | None] = ContextVar("mcp_current_user_id", default=None)

mcp = FastMCP(
    "Takt",
    instructions=(
        "Work with the caller's Takt projects and tasks. Respect project membership. "
        "Before destructive changes, confirm with the user."
    ),
    streamable_http_path="/mcp",
    stateless_http=True,
)


class TaktMCPAuth:
    """Verify each MCP HTTP request with the same access JWT used by Takt clients."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers", []))
        authorization = headers.get(b"authorization", b"").decode("latin-1")
        scheme, _, raw_token = authorization.partition(" ")
        bearer = raw_token.strip() if scheme.lower() == "bearer" else ""
        payload = decode_token(bearer) if bearer else None
        if bearer and payload is None:
            # OAuth access tokens carry an audience; decode_token for regular Takt
            # API tokens intentionally has no MCP-specific audience configured.
            settings = get_settings()
            try:
                payload = jwt.decode(
                    bearer,
                    settings.SECRET_KEY,
                    algorithms=[settings.JWT_ALGORITHM],
                    options={"verify_aud": False},
                )
            except JWTError:
                payload = None
        user_id: uuid.UUID | None = None
        if payload and payload.get("type") == "access":
            if payload.get("oauth_client_id"):
                settings = get_settings()
                expected_issuer = settings.APP_PUBLIC_URL.rstrip("/")
                expected_resource = f"{expected_issuer}/mcp"
                scopes = str(payload.get("scope") or "").split()
                if (
                    payload.get("iss") != expected_issuer
                    or payload.get("aud") != expected_resource
                    or "mcp" not in scopes
                ):
                    payload = None
            if payload:
                try:
                    user_id = uuid.UUID(payload["sub"])
                except (KeyError, ValueError, TypeError):
                    user_id = None

        if user_id is not None:
            async with AsyncSessionLocal() as db:
                user = await db.get(User, user_id)
                if user is None or not user.is_active:
                    user_id = None

        if user_id is None:
            body = json.dumps({"error": "Authentication required"}).encode()
            metadata = (
                f'{get_settings().APP_PUBLIC_URL.rstrip("/")}'
                "/.well-known/oauth-protected-resource"
            )
            await send(
                {
                    "type": "http.response.start",
                    "status": 401,
                    "headers": [
                        (b"content-type", b"application/json"),
                        (
                            b"www-authenticate",
                            f'Bearer realm="Takt MCP", resource_metadata="{metadata}"'.encode(),
                        ),
                        (b"content-length", str(len(body)).encode()),
                    ],
                }
            )
            await send({"type": "http.response.body", "body": body})
            return

        context_token = _current_user_id.set(user_id)
        try:
            await self.app(scope, receive, send)
        finally:
            _current_user_id.reset(context_token)


def _required_uuid(raw: str, field: str) -> uuid.UUID:
    try:
        return uuid.UUID(raw)
    except (ValueError, TypeError) as exc:
        raise ValueError(f"{field} must be a UUID") from exc


async def _identity() -> tuple[Any, User]:
    user_id = _current_user_id.get()
    if user_id is None:
        raise PermissionError("Authentication required")
    db = AsyncSessionLocal()
    user = await db.get(User, user_id)
    if user is None or not user.is_active:
        await db.close()
        raise PermissionError("Authentication required")
    return db, user


def _json(model: Any) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump(mode="json")
    return model


@mcp.tool()
async def list_projects(include_archived: bool = False) -> list[dict[str, Any]]:
    """List projects the authenticated Takt user belongs to."""
    db, user = await _identity()
    try:
        projects = await project_service.list_projects_for_user(
            db, user, include_archived=include_archived
        )
        return [
            {
                "id": str(project.id),
                "name": project.name,
                "description": project.description,
                "is_archived": project.is_archived,
                "role": next(
                    (
                        str(member.role.value)
                        for member in project.members
                        if member.user_id == user.id
                    ),
                    None,
                ),
            }
            for project in projects
        ]
    finally:
        await db.close()


@mcp.tool()
async def get_project_board(project_id: str) -> dict[str, Any]:
    """Get a project with its columns and current tasks."""
    from app.api.v1.tasks import list_tasks_route

    db, user = await _identity()
    try:
        pid = _required_uuid(project_id, "project_id")
        await project_service.ensure_project_access(db, user, pid)
        project = await project_service.get_project(db, pid)
        if project is None:
            raise ValueError("Project not found")
        columns = (
            (
                await db.execute(
                    select(TaskStatus)
                    .where(TaskStatus.project_id == pid)
                    .order_by(TaskStatus.position, TaskStatus.name)
                )
            )
            .scalars()
            .all()
        )
        task_result = await list_tasks_route(
            user=user,
            db=db,
            project_id=pid,
            page=1,
            page_size=1000,
        )
        return {
            "project": {
                "id": str(project.id),
                "name": project.name,
                "description": project.description,
                "is_archived": project.is_archived,
            },
            "columns": [_json(status_to_out(column)) for column in columns],
            "tasks": [_json(task) for task in task_result["items"]],
            "total_tasks": task_result["total"],
        }
    finally:
        await db.close()


@mcp.tool()
async def list_tasks(
    project_id: str | None = None,
    search: str | None = None,
    status_id: str | None = None,
    assignee_id: str | None = None,
    priority: str | None = None,
    include_archived: bool = False,
    page: int = 1,
    page_size: int = 100,
) -> dict[str, Any]:
    """Search tasks in projects available to the authenticated user."""
    from app.api.v1.tasks import list_tasks_route
    from app.models.task import TaskPriority

    db, user = await _identity()
    try:
        result = await list_tasks_route(
            user=user,
            db=db,
            search=search,
            project_id=_required_uuid(project_id, "project_id") if project_id else None,
            status_id=_required_uuid(status_id, "status_id") if status_id else None,
            assignee_id=_required_uuid(assignee_id, "assignee_id") if assignee_id else None,
            priority=TaskPriority(priority) if priority else None,
            include_archived=include_archived,
            page=max(page, 1),
            page_size=max(1, min(page_size, 100)),
        )
        return {**result, "items": [_json(task) for task in result["items"]]}
    finally:
        await db.close()


@mcp.tool()
async def get_task(task_id: str) -> dict[str, Any]:
    """Get a task, including its assignees, labels, checklist, and status."""
    from app.api.v1.tasks import get_task_route

    db, user = await _identity()
    try:
        result = await get_task_route(_required_uuid(task_id, "task_id"), user, db)
        return _json(result["task"])
    finally:
        await db.close()


@mcp.tool()
async def create_task(
    project_id: str,
    status_id: str,
    title: str,
    assignee_ids: list[str],
    description: str | None = None,
    priority: str = "medium",
    due_date: str | None = None,
    label_names: list[str] | None = None,
) -> dict[str, Any]:
    """Create a task in a project. At least one project-member assignee is required."""
    from app.api.v1.tasks import create_task as create_task_route
    from app.models.task import TaskPriority

    db, user = await _identity()
    try:
        due = datetime.fromisoformat(due_date.replace("Z", "+00:00")) if due_date else None
        body = TaskCreate(
            project_id=_required_uuid(project_id, "project_id"),
            status_id=_required_uuid(status_id, "status_id"),
            title=title,
            description=description,
            priority=TaskPriority(priority),
            due_date=due,
            assignee_ids=[_required_uuid(item, "assignee_id") for item in assignee_ids],
            label_names=label_names or [],
        )
        result = await create_task_route(body=body, user=user, db=db)
        return _json(result["task"])
    finally:
        await db.close()


@mcp.tool()
async def update_task(
    task_id: str,
    title: str | None = None,
    description: str | None = None,
    status_id: str | None = None,
    priority: str | None = None,
    clear_description: bool = False,
    assignee_ids: list[str] | None = None,
    label_names: list[str] | None = None,
    due_date: str | None = None,
    clear_due_date: bool = False,
    archived: bool | None = None,
) -> dict[str, Any]:
    """Edit task fields. Set clear_due_date=true to remove its due date."""
    from app.api.v1.tasks import update_task as update_task_route
    from app.models.task import TaskPriority

    db, user = await _identity()
    try:
        fields: dict[str, Any] = {
            "title": title,
            "priority": TaskPriority(priority) if priority else None,
            "assignee_ids": (
                [_required_uuid(item, "assignee_id") for item in assignee_ids]
                if assignee_ids is not None
                else None
            ),
            "label_names": label_names,
            "archived": archived,
        }
        if status_id is not None:
            fields["status_id"] = _required_uuid(status_id, "status_id")
        if clear_description:
            fields["description"] = None
        elif description is not None:
            fields["description"] = description
        if clear_due_date:
            fields["due_date"] = None
        elif due_date is not None:
            fields["due_date"] = datetime.fromisoformat(due_date.replace("Z", "+00:00"))
        body = TaskUpdate(
            **{
                key: value
                for key, value in fields.items()
                if value is not None or key in {"description", "due_date"}
            }
        )
        result = await update_task_route(_required_uuid(task_id, "task_id"), body, user, db)
        return _json(result["task"])
    finally:
        await db.close()


@mcp.tool()
async def move_task(task_id: str, status_id: str, position: float | None = None) -> dict[str, Any]:
    """Move a task to a project column; omitted position places it at the top."""
    from app.api.v1.tasks import move_task as move_task_route

    db, user = await _identity()
    try:
        destination_id = _required_uuid(status_id, "status_id")
        target_position = (
            position
            if position is not None
            else await task_service.next_position(db, destination_id)
        )
        result = await move_task_route(
            _required_uuid(task_id, "task_id"),
            TaskMove(status_id=destination_id, position=target_position),
            user,
            db,
        )
        return _json(result["task"])
    finally:
        await db.close()


@mcp.tool()
async def list_task_comments(task_id: str) -> list[dict[str, Any]]:
    """List comments on a task the authenticated user can access."""
    from app.api.v1.tasks import list_comments

    db, user = await _identity()
    try:
        result = await list_comments(_required_uuid(task_id, "task_id"), user, db)
        return [_json(comment) for comment in result["items"]]
    finally:
        await db.close()


@mcp.tool()
async def add_task_comment(
    task_id: str,
    body: str,
    mention_user_ids: list[str] | None = None,
) -> dict[str, Any]:
    """Add a comment to a task, optionally mentioning project members by user ID."""
    from app.api.v1.tasks import add_comment

    db, user = await _identity()
    try:
        payload = CommentCreate(
            body=body,
            mention_user_ids=[
                _required_uuid(item, "mention_user_id") for item in (mention_user_ids or [])
            ],
        )
        result = await add_comment(_required_uuid(task_id, "task_id"), payload, user, db)
        return _json(result["comment"])
    finally:
        await db.close()


@mcp.tool()
async def add_checklist_item(task_id: str, title: str) -> dict[str, Any]:
    """Add an unchecked checklist item to a task."""
    from app.api.v1.tasks import add_checklist

    db, user = await _identity()
    try:
        result = await add_checklist(
            _required_uuid(task_id, "task_id"), ChecklistCreate(title=title), user, db
        )
        return result["item"]
    finally:
        await db.close()


@mcp.tool()
async def update_checklist_item(
    task_id: str,
    item_id: str,
    title: str | None = None,
    is_done: bool | None = None,
    position: float | None = None,
) -> dict[str, Any]:
    """Rename, complete, or reorder a checklist item."""
    from app.api.v1.tasks import update_checklist

    db, user = await _identity()
    try:
        body = ChecklistUpdate(title=title, is_done=is_done, position=position)
        result = await update_checklist(
            _required_uuid(task_id, "task_id"),
            _required_uuid(item_id, "item_id"),
            body,
            user,
            db,
        )
        return result["item"]
    finally:
        await db.close()


@mcp.tool()
async def delete_task(task_id: str) -> dict[str, Any]:
    """Delete a task authored by the current user (soft delete)."""
    from app.api.v1.tasks import delete_task as delete_task_route

    db, user = await _identity()
    try:
        return await delete_task_route(_required_uuid(task_id, "task_id"), user, db)
    finally:
        await db.close()


def create_mcp_asgi_app() -> ASGIApp:
    """Return the MCP endpoint wrapped in Takt JWT authentication."""
    return TaktMCPAuth(mcp.streamable_http_app())
