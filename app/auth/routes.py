from fastapi import APIRouter, HTTPException, status

from app.auth.schemas import LoginRequest, LoginResponse
from app.auth.utils import create_token
from app.core.config import JWT_ALG, JWT_SECRET, JWT_TTL_SECONDS, USERS

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest):
    user = USERS.get(payload.username)
    if not user or user["password"] != payload.password:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_token(payload.username, user["role"], JWT_SECRET, JWT_ALG, JWT_TTL_SECONDS)
    return LoginResponse(token=token, role=user["role"])
