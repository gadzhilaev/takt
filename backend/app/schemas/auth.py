from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class ForceChangePasswordRequest(BaseModel):
    new_password: str = Field(min_length=8, max_length=128)


class UserPublic(BaseModel):
    id: str
    email: str
    name: str
    role: str
    avatar_url: str | None
    must_change_password: bool

    model_config = {"from_attributes": True}
