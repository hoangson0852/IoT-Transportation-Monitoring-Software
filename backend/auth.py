"""
===============================================================================
MODULE XÁC THỰC BẢO MẬT & PHÂN QUYỀN (JWT SECURITY & AUTHENTICATION MODULE)
Backend Server - Đồ án Tốt nghiệp 2026
===============================================================================
"""

import os
import json
import hmac
import hashlib
import base64
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

import models
from database import get_db

# App Security Secret Key & Configuration
JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-key-datn-2026")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def hash_password(password: str) -> str:
    """Mã hóa mật khẩu bằng SHA-256 + HMAC Salt"""
    return hmac.new(JWT_SECRET.encode(), password.encode(), hashlib.sha256).hexdigest()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Kiểm tra mật khẩu khớp với bản mã hóa"""
    if hashed_password == plain_password:
        return True  # Fallback cho tài khoản thử nghiệm chưa mã hóa
    return hmac.compare_digest(hash_password(plain_password), hashed_password)

def create_jwt_token(data: dict, expires_hours: int = ACCESS_TOKEN_EXPIRE_HOURS) -> str:
    """Tạo mã JWT Token chuẩn HS256"""
    header = base64.urlsafe_b64encode(json.dumps({"alg": ALGORITHM, "typ": "JWT"}).encode()).decode().rstrip("=")
    payload_data = data.copy()
    payload_data["exp"] = int((datetime.utcnow() + timedelta(hours=expires_hours)).timestamp())
    payload_data["iat"] = int(datetime.utcnow().timestamp())
    payload = base64.urlsafe_b64encode(json.dumps(payload_data).encode()).decode().rstrip("=")
    
    signature_input = f"{header}.{payload}".encode()
    signature = base64.urlsafe_b64encode(hmac.new(JWT_SECRET.encode(), signature_input, hashlib.sha256).digest()).decode().rstrip("=")
    return f"{header}.{payload}.{signature}"

def verify_jwt_token(token: str) -> Optional[dict]:
    """Giải mã và xác thực chữ ký JWT Token"""
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        header, payload, signature = parts
        signature_input = f"{header}.{payload}".encode()
        expected_sig = base64.urlsafe_b64encode(hmac.new(JWT_SECRET.encode(), signature_input, hashlib.sha256).digest()).decode().rstrip("=")
        if not hmac.compare_digest(signature, expected_sig):
            return None
        padded_payload = payload + "=" * (-len(payload) % 4)
        data = json.loads(base64.urlsafe_b64decode(padded_payload).decode())
        if data.get("exp", 0) < int(datetime.utcnow().timestamp()):
            return None
        return data
    except Exception:
        return None

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> models.User:
    """Dependency xác thực JWT Token và trả về thông tin User đang đăng nhập"""
    payload = verify_jwt_token(token)
    if not payload or "email" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": "Token xác thực không hợp lệ hoặc đã hết hạn."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = db.query(models.User).filter(models.User.email == payload["email"]).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "USER_NOT_FOUND", "message": "Người dùng không tồn tại trên hệ thống."},
        )
    return user

def require_admin(current_user: models.User = Depends(get_current_user)) -> models.User:
    """Dependency kiểm tra quyền Admin"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "FORBIDDEN_ROLE", "message": "Yêu cầu quyền Admin để thực hiện thao tác này."},
        )
    return current_user
