import time
from typing import Set

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

ROLE_ADMIN = "admin"
ROLE_DEVELOPER = "developer"
ROLE_VIEWER = "viewer"

ALLOWED_ROLES: Set[str] = {ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER}

security = HTTPBearer()


class AuthContext(BaseModel):
    username: str
    role: str


def create_token(username: str, role: str, secret: str, alg: str, ttl_seconds: int) -> str:
    now = int(time.time())
    payload = {
        "sub": username,
        "role": role,
        "iat": now,
        "exp": now + ttl_seconds,
    }
    return jwt.encode(payload, secret, algorithm=alg)


def parse_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> AuthContext:
    token = credentials.credentials
    try:
        from app.core.config import JWT_ALG, JWT_SECRET

        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
    except jwt.PyJWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    role = payload.get("role")
    if role not in ALLOWED_ROLES:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid role")

    return AuthContext(username=payload.get("sub", ""), role=role)


def require_roles(*roles: str):
    def _check(ctx: AuthContext = Depends(parse_token)) -> AuthContext:
        if ctx.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return ctx

    return _check
