import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, verify_csrf
from app.db.session import get_db
from app.models.invite import ProjectInvite, ProjectInviteStatus
from app.models.project import Project, ProjectMemberRole
from app.models.user import User
from app.schemas.invite import InviteCreate, InviteOut, InvitePublicOut
from app.services import invite_service, project_service

router = APIRouter(tags=["invites"])


def _invite_out(
    invite: ProjectInvite,
    *,
    project_name: str | None = None,
    invited_by_name: str | None = None,
    include_token: bool = False,
) -> InviteOut:
    return InviteOut(
        id=str(invite.id),
        project_id=str(invite.project_id),
        project_name=project_name,
        email=invite.email,
        status=invite.status.value,
        invited_by_name=invited_by_name,
        created_at=invite.created_at,
        invitee_registered=invite.invitee_user_id is not None,
        token=invite.token if include_token else None,
    )


@router.get("/invites/mine")
async def my_invites(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    invites = await invite_service.list_pending_for_user(db, user)
    items = []
    for inv in invites:
        project = await db.get(Project, inv.project_id)
        inviter = await db.get(User, inv.invited_by_id)
        items.append(
            _invite_out(
                inv,
                project_name=project.name if project else None,
                invited_by_name=inviter.name if inviter else None,
            )
        )
    return {"items": items}


@router.get("/invites/token/{token}")
async def invite_by_token(
    token: str,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Публичные сведения по ссылке-приглашению (без авторизации)."""
    invite = await invite_service.get_invite_by_token(db, token)
    if not invite or invite.status != ProjectInviteStatus.pending:
        raise HTTPException(
            status_code=404,
            detail={
                "error": {
                    "code": "not_found",
                    "message": "Приглашение не найдено или уже использовано",
                }
            },
        )
    project = await db.get(Project, invite.project_id)
    inviter = await db.get(User, invite.invited_by_id)
    return InvitePublicOut(
        project_id=str(invite.project_id),
        project_name=project.name if project else None,
        email=invite.email,
        status=invite.status.value,
        invited_by_name=inviter.name if inviter else None,
        requires_email_match=invite.email is not None,
    )


@router.post("/invites/token/{token}/accept", dependencies=[Depends(verify_csrf)])
async def accept_invite_by_token(
    token: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    invite = await invite_service.get_invite_by_token(db, token)
    if not invite:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}})
    try:
        await invite_service.accept_invite(db, invite, user)
    except invite_service.InviteError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True, "project_id": str(invite.project_id)}


@router.post("/invites/{invite_id}/accept", dependencies=[Depends(verify_csrf)])
async def accept_invite(
    invite_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    invite = await db.get(ProjectInvite, invite_id)
    if not invite:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}})
    try:
        await invite_service.accept_invite(db, invite, user)
    except invite_service.InviteError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True, "project_id": str(invite.project_id)}


@router.post("/invites/{invite_id}/decline", dependencies=[Depends(verify_csrf)])
async def decline_invite(
    invite_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    invite = await db.get(ProjectInvite, invite_id)
    if not invite:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}})
    try:
        await invite_service.decline_invite(db, invite, user)
    except invite_service.InviteError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True}


@router.get("/projects/{project_id}/invites")
async def list_project_invites(
    project_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await project_service.ensure_project_access(
            db, user, project_id, min_role=ProjectMemberRole.admin
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    project = await db.get(Project, project_id)
    invites = await invite_service.list_project_invites(db, project_id)
    return {
        "items": [
            _invite_out(
                i,
                project_name=project.name if project else None,
                include_token=True,
            )
            for i in invites
            if i.status == ProjectInviteStatus.pending
        ]
    }


@router.post("/projects/{project_id}/invites", dependencies=[Depends(verify_csrf)])
async def create_project_invite(
    project_id: uuid.UUID,
    body: InviteCreate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    project = await project_service.get_project(db, project_id)
    if not project:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Проект не найден"}})
    try:
        invite = await invite_service.create_invite(
            db, project=project, email=str(body.email) if body.email else None, invited_by=user
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Только владелец"}})
    except invite_service.InviteError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    note = (
        "Скопируйте ссылку и отправьте сотруднику — после входа он вступит в проект."
        if invite.email is None
        else (
            "Приглашение появится у человека в приложении после входа с этим email. "
            "Можно также отправить ссылку."
        )
    )
    return {
        "invite": _invite_out(
            invite,
            project_name=project.name,
            invited_by_name=user.name,
            include_token=True,
        ),
        "email_delivery": "in_app_only",
        "note": note,
    }


@router.delete("/projects/{project_id}/invites/{invite_id}", dependencies=[Depends(verify_csrf)])
async def cancel_project_invite(
    project_id: uuid.UUID,
    invite_id: uuid.UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    invite = await db.get(ProjectInvite, invite_id)
    if not invite or invite.project_id != project_id:
        raise HTTPException(status_code=404, detail={"error": {"code": "not_found", "message": "Не найдено"}})
    try:
        await invite_service.cancel_invite(db, invite, user)
    except PermissionError:
        raise HTTPException(status_code=403, detail={"error": {"code": "forbidden", "message": "Нет прав"}})
    except invite_service.InviteError as e:
        raise HTTPException(status_code=400, detail={"error": {"code": e.code, "message": e.message}})
    await db.commit()
    return {"ok": True}
