import os
from pathlib import Path
from typing import Dict, Optional, TypedDict
from uuid import uuid4

from dotenv import load_dotenv

from database import SessionLocal
import models
from auth_utils import hash_password

# 强制定位并加载当前目录下的 .env 文件
ENV_PATH = Path(__file__).resolve().parent / ".env"
load_dotenv(ENV_PATH, override=True)

# 此时 os.getenv 必定能读到 .env 中的值


class UserRecord(TypedDict):
    user_id: str
    email: str
    display_name: str
    password_hash: str
    is_active: bool


def _to_user_record(user: models.DBUser) -> UserRecord:
    return {
        "user_id": user.user_id,
        "email": user.email,
        "display_name": user.display_name,
        "password_hash": user.password_hash,
        "is_active": bool(user.is_active),
    }


def _build_demo_users() -> Dict[str, UserRecord]:
    demo_email = os.getenv("AUTH_DEMO_EMAIL")
    demo_password = os.getenv("AUTH_DEMO_PASSWORD")
    demo_name = os.getenv("AUTH_DEMO_NAME", "NavIA Demo User")
    demo_user_id = os.getenv("AUTH_DEMO_USER_ID", "user_demo_001")

    # 如果 .env 还是没读到，返回空字典，避免程序崩溃
    if not demo_email or not demo_password:
        return {}

    email_key = demo_email.strip().lower()

    return {
        email_key: {
            "user_id": demo_user_id,
            "email": email_key,
            "display_name": demo_name,
            "password_hash": hash_password(demo_password),
            "is_active": True
        }
    }


# 初始化演示用户字典
_DEMO_USERS = _build_demo_users()


def get_user_for_login(email: str) -> Optional[UserRecord]:
    email_key = email.strip().lower()

    db = SessionLocal()
    try:
        user = db.query(models.DBUser).filter(models.DBUser.email == email_key).first()
        if user is not None:
            return _to_user_record(user)
    finally:
        db.close()

    return _DEMO_USERS.get(email_key)


def get_user_by_id(user_id: str) -> Optional[UserRecord]:
    db = SessionLocal()
    try:
        user = db.query(models.DBUser).filter(models.DBUser.user_id == user_id).first()
        if user is not None:
            return _to_user_record(user)
    finally:
        db.close()

    for u in _DEMO_USERS.values():
        if u["user_id"] == user_id:
            return u

    return None


def get_user_by_email(email: str) -> Optional[UserRecord]:
    email_key = email.strip().lower()

    db = SessionLocal()
    try:
        user = db.query(models.DBUser).filter(models.DBUser.email == email_key).first()
        if user is not None:
            return _to_user_record(user)
    finally:
        db.close()

    return _DEMO_USERS.get(email_key)


def create_user(email: str, display_name: str, password: str) -> UserRecord:
    email_key = email.strip().lower()
    clean_display_name = display_name.strip()

    if email_key in _DEMO_USERS:
        raise ValueError("该邮箱已被演示账号占用")

    db = SessionLocal()
    try:
        existing = db.query(models.DBUser).filter(models.DBUser.email == email_key).first()
        if existing is not None:
            raise ValueError("该邮箱已注册")

        new_user = models.DBUser(
            user_id=f"user_{uuid4().hex[:8]}",
            email=email_key,
            display_name=clean_display_name,
            password_hash=hash_password(password),
            is_active=True,
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        return _to_user_record(new_user)
    finally:
        db.close()