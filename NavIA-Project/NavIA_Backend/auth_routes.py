import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from auth_store import create_user, get_user_by_email, get_user_by_id, get_user_for_login
from auth_utils import create_access_token, decode_access_token, verify_password

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])
bearer_scheme = HTTPBearer(auto_error=False)


class RegisterRequest(BaseModel):
    email: str
    display_name: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_seconds: int
    user_id: str
    email: str
    display_name: str


class UserPublic(BaseModel):
    user_id: str
    email: str
    display_name: str


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme)
) -> UserPublic:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="缺少 Bearer Token")

    payload = decode_access_token(credentials.credentials)
    user = get_user_by_id(payload["sub"])

    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="用户不存在或已失效")

    return UserPublic(
        user_id=user["user_id"],
        email=user["email"],
        display_name=user["display_name"]
    )


@router.post("/register", response_model=AuthTokenResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest) -> AuthTokenResponse:
    email = req.email.strip().lower()
    display_name = req.display_name.strip()
    password = req.password

    if not email:
        raise HTTPException(status_code=400, detail="邮箱不能为空")
    if "@" not in email:
        raise HTTPException(status_code=400, detail="邮箱格式不正确")
    if len(display_name) < 2:
        raise HTTPException(status_code=400, detail="用户名至少 2 个字符")
    if len(password) < 6:
        raise HTTPException(status_code=400, detail="密码至少 6 位")

    existing = get_user_by_email(email)
    if existing is not None:
        raise HTTPException(status_code=400, detail="该邮箱已被注册")

    try:
        user = create_user(email, display_name, password)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    token = create_access_token(user["user_id"], user["email"], user["display_name"])
    expires = int(60 * int(os.getenv("AUTH_TOKEN_EXPIRE_MINUTES", "60")))

    return AuthTokenResponse(
        access_token=token,
        expires_in_seconds=expires,
        user_id=user["user_id"],
        email=user["email"],
        display_name=user["display_name"]
    )


@router.post("/login", response_model=AuthTokenResponse)
def login(req: LoginRequest) -> AuthTokenResponse:
    user = get_user_for_login(req.email)

    if user is None or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="邮箱或密码错误")

    if not user["is_active"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="账号已被禁用")

    token = create_access_token(user["user_id"], user["email"], user["display_name"])
    expires = int(60 * int(os.getenv("AUTH_TOKEN_EXPIRE_MINUTES", "60")))

    return AuthTokenResponse(
        access_token=token,
        expires_in_seconds=expires,
        user_id=user["user_id"],
        email=user["email"],
        display_name=user["display_name"]
    )


@router.get("/me", response_model=UserPublic)
def me(current_user: UserPublic = Depends(get_current_user)) -> UserPublic:
    return current_user