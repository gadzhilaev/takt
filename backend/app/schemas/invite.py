from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class InviteCreate(BaseModel):
    email: EmailStr


class InviteOut(BaseModel):
    id: str
    project_id: str
    project_name: str | None = None
    email: str
    status: str
    invited_by_name: str | None = None
    created_at: datetime
    invitee_registered: bool = False
