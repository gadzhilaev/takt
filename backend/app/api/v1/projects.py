import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, verify_csrf
from app.api.serializers import avatar_url
from app.db.session import get_db
from app.models.project import ProjectMember, ProjectMemberRole
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectMemberUpdate, ProjectOut, ProjectUpdate
from app.services import leave_request_service, project_service
from app.services.leave_request_service import LeaveRequestError

router = APIRouter(prefix="/projects", tags=["projects"])


def _project_out(project, members_users: dict[uuid.UUID, User], progress: dict | None = None) -> ProjectOut:
    members = []
    for m in project.members or []:
        u = members_users.get(m.user_id)
        if not u:
            continue
        members.append(
            {
                "user_id": str(m.user_id),
                "role": m.role,
                "name": u.name,
                "email": u.email,
                "avatar_url": avatar_url(u),
            }
        )
    return ProjectOut(
        id=str(project.id),
        name=project.name,
        description=project.description,
        color=project.color,
        icon=project.icon,
        is_default=project.is_default,
        is_archived=project.is_archived,
        is_demo=bool(getattr(project, "is_demo", False)),
        auto_urgency_from_due=bool(getattr(project, "auto_urgency_from_due", True)),
        created_at=project.created_at,
        updated_at=project.updated_at,
        members=members,
        progress=progress,
    )


async def _users_map(db: AsyncSession, user_ids: list[uuid.UUID]) -> dict[uuid.UUID, User]:
    if not user_ids:
        return {}
    rows = (await db.execute(select(User).where(User.id.in_(user_ids)))).scalars().all()
    return {u.id: u for u in rows}


@router.get("")
async def list_projects(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    include_archived: bool = False,
):
    projects = await project_service.list_projects_for_user(
        db, user, include_archived=include_archived
    )
    items = []
    for p in projects:
        umap = await _users_map(db, [m.user_id for m in p.members])
        progress = await project_service.project_progress(db, p.id)
        items.append(_project_out(p, umap, progress))
    return {"items": items}


@router.post("", dependencies=[Depends(verify_csrf)])
async def create_project(
    body: ProjectCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    project = await project_service.create_project(
        db,
        name=body.name,
        description=body.description,
        color=body.color,
        icon=body.icon,
        creator=user,
        member_ids=body.member_ids,
    )
    await db.commit()
    project = await project_service.get_project(db, project.id)
    umap = await _users_map(db, [m.user_id for m in project.members])  # type: ignore[union-attr]
    progress = await project_service.project_progress(db, project.id)  # type: ignore[union-attr]
    return {"project": _project_out(project, umap, progress)}


@router.get("/{project_id}")
async def get_project(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await project_service.ensure_project_access(db, user, project_id)
    except PermissionError as e:
        if str(e) == "project_restricted":
            raise HTTPException(
                status_code=403,
                detail={
                    "error": {
                        "code": "project_restricted",
                        "message": "Проект ограничен администратором платформы",
                    }
                },
            )
        raise HTTPException(
            status_code=403,
            detail={"error": {"code": "forbidden", "message": "Нет доступа к проекту"}},
        )
    project = await project_service.get_project(db, project_id)
    if not project:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Проект не найден"}})
    umap = await _users_map(db, [m.user_id for m in project.members])
    progress = await project_service.project_progress(db, project.id)
    return {"project": _project_out(project, umap, progress)}


@router.patch("/{project_id}", dependencies=[Depends(verify_csrf)])
async def update_project(
    project_id: uuid.UUID,
    body: ProjectUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await project_service.ensure_project_access(
            db, user, project_id, min_role=ProjectMemberRole.admin
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нужны права администратора проекта"}})
    project = await project_service.get_project(db, project_id)
    if not project:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Проект не найден"}})
    if body.name is not None:
        project.name = body.name
    if body.description is not None:
        project.description = body.description
    if body.color is not None:
        project.color = body.color
    if body.icon is not None:
        project.icon = body.icon
    if body.is_archived is not None:
        if project.is_default and body.is_archived:
            raise HTTPException(
                status_code=400,
                detail={"error": {"code": "default_project", "message": "Нельзя архивировать проект «Общее»"}},
            )
        project.is_archived = body.is_archived
    if body.auto_urgency_from_due is not None:
        project.auto_urgency_from_due = body.auto_urgency_from_due
    await db.commit()
    project = await project_service.get_project(db, project_id)
    umap = await _users_map(db, [m.user_id for m in project.members])  # type: ignore[union-attr]
    progress = await project_service.project_progress(db, project.id)  # type: ignore[union-attr]
    return {"project": _project_out(project, umap, progress)}


@router.delete("/{project_id}", dependencies=[Depends(verify_csrf)])
async def delete_project(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await project_service.delete_project(db, project_id=project_id, actor=user)
    except PermissionError as e:
        code = str(e) if str(e) in {"default_project", "forbidden"} else "forbidden"
        messages = {
            "default_project": "Нельзя удалить проект «Общее»",
            "forbidden": "Нужны права администратора проекта",
        }
        raise HTTPException(
            status_code=400 if code == "default_project" else 403,
            detail={"error": {"code": code, "message": messages.get(code, "Нет прав")}},
        )
    except LookupError:
        raise HTTPException(
            status_code=404,
            detail={"error": {"code": "not_found", "message": "Проект не найден"}},
        )
    await db.commit()
    return {"ok": True}


@router.post("/{project_id}/leave", dependencies=[Depends(verify_csrf)])
async def leave_project(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await leave_request_service.leave_project_now(db, project_id=project_id, user=user)
    except PermissionError:
        raise HTTPException(
            status_code=403,
            detail={"error": {"code": "forbidden", "message": "Нет доступа"}},
        )
    except LeaveRequestError as e:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": e.code, "message": e.message}},
        )
    await db.commit()
    return {"ok": True}


@router.put("/{project_id}/members", dependencies=[Depends(verify_csrf)])
async def set_members(
    project_id: uuid.UUID,
    body: list[ProjectMemberUpdate],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await project_service.ensure_project_access(
            db, user, project_id, min_role=ProjectMemberRole.admin
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    await db.execute(delete(ProjectMember).where(ProjectMember.project_id == project_id))
    for m in body:
        db.add(ProjectMember(project_id=project_id, user_id=m.user_id, role=m.role))
    await db.commit()
    project = await project_service.get_project(db, project_id)
    umap = await _users_map(db, [m.user_id for m in project.members])  # type: ignore[union-attr]
    return {"project": _project_out(project, umap)}


def _leave_out(req, user: User | None) -> dict:
    return {
        "id": str(req.id),
        "project_id": str(req.project_id),
        "user_id": str(req.user_id),
        "user_name": user.name if user else "",
        "avatar_url": avatar_url(user) if user else None,
        "status": req.status.value if hasattr(req.status, "value") else str(req.status),
        "created_at": req.created_at.isoformat() if req.created_at else None,
    }


@router.delete("/{project_id}/members/{user_id}", dependencies=[Depends(verify_csrf)])
async def remove_member(
    project_id: uuid.UUID,
    user_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await leave_request_service.remove_member(
            db, project_id=project_id, target_user_id=user_id, actor=user
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    except LeaveRequestError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    project = await project_service.get_project(db, project_id)
    umap = await _users_map(db, [m.user_id for m in project.members])  # type: ignore[union-attr]
    return {"project": _project_out(project, umap)}


@router.post("/{project_id}/leave-requests", dependencies=[Depends(verify_csrf)])
async def create_leave_request(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        req = await leave_request_service.create_leave_request(db, project_id=project_id, user=user)
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет доступа"}})
    except LeaveRequestError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    await db.refresh(req)
    return {"request": _leave_out(req, user)}


@router.get("/{project_id}/leave-requests")
async def list_leave_requests(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        items = await leave_request_service.list_leave_requests(db, project_id=project_id, user=user)
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    umap = await _users_map(db, [r.user_id for r in items])
    return {"items": [_leave_out(r, umap.get(r.user_id)) for r in items]}


@router.post("/{project_id}/leave-requests/{request_id}/approve", dependencies=[Depends(verify_csrf)])
async def approve_leave_request(
    project_id: uuid.UUID,
    request_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await leave_request_service.approve_leave_request(
            db, project_id=project_id, request_id=request_id, actor=user
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    except LeaveRequestError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True}


@router.post("/{project_id}/leave-requests/{request_id}/reject", dependencies=[Depends(verify_csrf)])
async def reject_leave_request(
    project_id: uuid.UUID,
    request_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await leave_request_service.reject_leave_request(
            db, project_id=project_id, request_id=request_id, actor=user
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    except LeaveRequestError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True}
