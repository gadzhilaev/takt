from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models.user import UserRole


class UserAdminCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    email: EmailStr
    role: UserRole = UserRole.member
    password: str | None = Field(default=None, min_length=8, max_length=128)
    must_change_password: bool = True


class UserAdminUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    email: EmailStr | None = None
    role: UserRole | None = None


class UserAdminResetPassword(BaseModel):
    password: str | None = Field(default=None, min_length=8, max_length=128)
    generate: bool = False
    must_change_password: bool = True


class UserAdminResponse(BaseModel):
    id: str
    email: str
    name: str
    role: str
    is_active: bool
    must_change_password: bool
    avatar_url: str | None
    created_at: datetime
    last_login_at: datetime | None

    model_config = {"from_attributes": True}


class UserCreateResult(BaseModel):
    user: UserAdminResponse
    temporary_password: str | None = None


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    email: EmailStr | None = None
