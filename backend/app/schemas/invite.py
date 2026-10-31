from datetime import datetime

from pydantic import BaseModel, EmailStr


class InviteCreate(BaseModel):
    """Email — персональное приглашение; без email — открытая ссылка в проект."""

    email: EmailStr | None = None


class InviteOut(BaseModel):
    id: str
    project_id: str
    project_name: str | None = None
    email: str | None = None
    status: str
    invited_by_name: str | None = None
    created_at: datetime
    invitee_registered: bool = False
    token: str | None = None


class InvitePublicOut(BaseModel):
    project_id: str
    project_name: str | None = None
    email: str | None = None
    status: str
    invited_by_name: str | None = None
    requires_email_match: bool = False
