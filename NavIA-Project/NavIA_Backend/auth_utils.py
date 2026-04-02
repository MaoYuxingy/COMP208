import base64
import hashlib
import hmac
import json
import os
import time
from typing import Optional

from fastapi import HTTPException, status


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _get_secret_key() -> str:
    return os.getenv("AUTH_SECRET_KEY", "navia-dev-secret-key")


def _get_expire_minutes() -> int:
    return int(os.getenv("AUTH_TOKEN_EXPIRE_MINUTES", "60"))


def _get_pbkdf2_iterations() -> int:
    return int(os.getenv("AUTH_PBKDF2_ITERATIONS", "100000"))


def hash_password(password: str, salt: Optional[bytes] = None) -> str:
    if salt is None:
        salt = os.urandom(16)

    iterations = _get_pbkdf2_iterations()
    derived_key = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        iterations
    )
    return (
        f"pbkdf2_sha256${iterations}$"
        f"{_b64url_encode(salt)}${_b64url_encode(derived_key)}"
    )


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations, salt_b64, expected_hash_b64 = stored_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False

        salt = _b64url_decode(salt_b64)
        derived_key = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt,
            int(iterations)
        )
        actual_hash_b64 = _b64url_encode(derived_key)
        return hmac.compare_digest(actual_hash_b64, expected_hash_b64)
    except Exception:
        return False


def create_access_token(user_id: str, email: str, display_name: str) -> str:
    issued_at = int(time.time())
    expires_at = issued_at + (_get_expire_minutes() * 60)

    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": user_id,
        "email": email,
        "name": display_name,
        "iat": issued_at,
        "exp": expires_at
    }

    header_segment = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_segment = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_segment}.{payload_segment}".encode("utf-8")

    secret_key = _get_secret_key().encode("utf-8")
    signature = hmac.new(secret_key, signing_input, hashlib.sha256).digest()

    return f"{header_segment}.{payload_segment}.{_b64url_encode(signature)}"


def decode_access_token(token: str) -> dict:
    try:
        header_segment, payload_segment, signature_segment = token.split(".", 2)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token 格式错误")

    signing_input = f"{header_segment}.{payload_segment}".encode("utf-8")
    secret_key = _get_secret_key().encode("utf-8")
    expected_sig = hmac.new(secret_key, signing_input, hashlib.sha256).digest()

    if not hmac.compare_digest(_b64url_encode(expected_sig), signature_segment):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token 签名无效")

    payload = json.loads(_b64url_decode(payload_segment).decode("utf-8"))
    now = int(time.time())
    if "exp" not in payload or now >= int(payload["exp"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token 已过期")

    return payload
