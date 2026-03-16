import os
from pathlib import Path
from typing import Dict, Optional, TypedDict

from dotenv import load_dotenv

# 强制定位并加载当前目录下的 .env 文件
ENV_PATH = Path(__file__).resolve().parent / ".env"
load_dotenv(ENV_PATH, override=True)

# 此时 os.getenv 必定能读到 .env 中的值
from auth_utils import hash_password

class UserRecord(TypedDict):
    user_id: str
    email: str
    display_name: str
    password_hash: str
    is_active: bool

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
    return _DEMO_USERS.get(email.strip().lower())

def get_user_by_id(user_id: str) -> Optional[UserRecord]:
    for u in _DEMO_USERS.values():
        if u["user_id"] == user_id:
            return u
    return None