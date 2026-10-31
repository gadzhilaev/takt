from pydantic import BaseModel, EmailStr, Field, model_validator


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    password_confirm: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def passwords_match(self):
        if self.password != self.password_confirm:
            raise ValueError("Пароли не совпадают")
        return self


class RegisterConfirmRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=12)
    # Токен из /invite/{token} — сразу вступить в проект после регистрации.
    invite_token: str | None = Field(default=None, max_length=128)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)
    new_password_confirm: str | None = Field(default=None, min_length=8, max_length=128)

    @model_validator(mode="after")
    def passwords_match(self):
        if self.new_password_confirm is not None and self.new_password != self.new_password_confirm:
            raise ValueError("Пароли не совпадают")
        return self


class ChangePasswordConfirmRequest(BaseModel):
    code: str = Field(min_length=4, max_length=12)


class ForgotPasswordSendRequest(BaseModel):
    email: EmailStr


class ForgotPasswordConfirmRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=12)
    new_password: str = Field(min_length=8, max_length=128)
    new_password_confirm: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def passwords_match(self):
        if self.new_password != self.new_password_confirm:
            raise ValueError("Пароли не совпадают")
        return self


class ForceChangePasswordRequest(BaseModel):
    new_password: str = Field(min_length=8, max_length=128)


class UserPublic(BaseModel):
    id: str
    email: str
    name: str
    role: str
    platform_role: str = "none"
    avatar_url: str | None
    must_change_password: bool

    model_config = {"from_attributes": True}
