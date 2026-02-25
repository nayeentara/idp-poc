from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.utils import ROLE_ADMIN, ROLE_DEVELOPER, require_roles
from app.core.deps import get_db
from app.deploy.schemas import DeployResponse
from app.services.models import ServiceModel

router = APIRouter(prefix="/services", tags=["deploy"])


def _ensure_service(db: Session, service_id: int) -> None:
    if not db.get(ServiceModel, service_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")


@router.post("/{service_id}/actions/deploy", response_model=DeployResponse)
def deploy(
    service_id: int,
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER)),
    db: Session = Depends(get_db),
):
    _ensure_service(db, service_id)
    return DeployResponse(
        service_id=service_id,
        action="deploy",
        status="queued",
        detail="Deployment queued",
    )
