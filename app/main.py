from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import APP_NAME
from app.db import Base, engine
from app.auth.routes import router as auth_router
from app.services.routes import router as services_router
from app.provisioning.routes import router as provisioning_router
from app.deploy.routes import router as deploy_router

app = FastAPI(title=APP_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(auth_router)
app.include_router(services_router)
app.include_router(provisioning_router)
app.include_router(deploy_router)

# Serve frontend
app.mount("/", StaticFiles(directory="frontend", html=True), name="frontend")
