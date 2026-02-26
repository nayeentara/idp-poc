from typing import List
from urllib.parse import quote_plus

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.utils import ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER, require_roles
from app.core.config import (
    OBSERVABILITY_GRAFANA_DASHBOARD_UID,
    OBSERVABILITY_GRAFANA_ORG_ID,
    OBSERVABILITY_GRAFANA_URL,
)
from app.core.deps import get_db
from app.services.models import ServiceModel
from app.services.schemas import Service, ServiceInput

router = APIRouter(prefix="/services", tags=["services"])


def _model_to_payload(row: ServiceModel) -> dict:
    dashboard_url = None
    if row.observability_enabled and OBSERVABILITY_GRAFANA_URL:
        service_var = quote_plus(row.name)
        dashboard_url = (
            f"{OBSERVABILITY_GRAFANA_URL}/d/{OBSERVABILITY_GRAFANA_DASHBOARD_UID}"
            f"?orgId={OBSERVABILITY_GRAFANA_ORG_ID}&var-service={service_var}&refresh=10s"
        )
    return {
        "name": row.name,
        "repo_url": row.repo_url,
        "owner_team": row.owner_team,
        "runtime": row.runtime,
        "tier": row.tier,
        "environments": row.environments or [],
        "tenant": row.tenant,
        "observability_enabled": row.observability_enabled,
        "observability_dashboard_url": dashboard_url,
        "provision_status": row.provision_status,
        "provision_detail": row.provision_detail,
    }


def _apply_payload(row: ServiceModel, payload: ServiceInput) -> None:
    row.name = payload.name
    row.repo_url = payload.repo_url
    row.owner_team = payload.owner_team
    row.runtime = payload.runtime
    row.tier = payload.tier
    row.environments = payload.environments
    row.tenant = payload.tenant
    row.observability_enabled = payload.observability_enabled


@router.get("", response_model=List[Service])
def list_services(
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER)),
    db: Session = Depends(get_db),
):
    rows = db.query(ServiceModel).order_by(ServiceModel.id.asc()).all()
    return [Service(id=row.id, **_model_to_payload(row)) for row in rows]


@router.post("", response_model=Service, status_code=status.HTTP_201_CREATED)
def create_service(
    payload: ServiceInput,
    _: str = Depends(require_roles(ROLE_ADMIN)),
    db: Session = Depends(get_db),
):
    row = ServiceModel(
        **payload.dict(),
        provision_status="not_requested",
        provision_detail="",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return Service(id=row.id, **_model_to_payload(row))


@router.get("/{service_id}", response_model=Service)
def get_service(
    service_id: int,
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER)),
    db: Session = Depends(get_db),
):
    row = db.get(ServiceModel, service_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    return Service(id=row.id, **_model_to_payload(row))


@router.put("/{service_id}", response_model=Service)
def update_service(
    service_id: int,
    payload: ServiceInput,
    _: str = Depends(require_roles(ROLE_ADMIN)),
    db: Session = Depends(get_db),
):
    row = db.get(ServiceModel, service_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    _apply_payload(row, payload)
    db.commit()
    db.refresh(row)
    return Service(id=row.id, **_model_to_payload(row))


@router.delete("/{service_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_service(
    service_id: int,
    _: str = Depends(require_roles(ROLE_ADMIN)),
    db: Session = Depends(get_db),
):
    row = db.get(ServiceModel, service_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    db.delete(row)
    db.commit()
    return None
