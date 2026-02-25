from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.auth.utils import ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER, require_roles
from app.core.config import CALLBACK_TOKEN, STEP_FUNCTION_ARN
from app.core.deps import get_db
from app.provisioning.models import ProvisionRequestModel, TenantModel
from app.provisioning.schemas import ActionResponse, ProvisionCallback, StatusResponse
from app.provisioning.service import get_or_create_tenant, start_step_function_execution
from app.services.models import ServiceModel

router = APIRouter(tags=["provisioning"])


def _ensure_service(db: Session, service_id: int) -> ServiceModel:
    service = db.get(ServiceModel, service_id)
    if not service:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    return service


@router.post("/services/{service_id}/actions/provision", response_model=ActionResponse)
def provision_env(
    service_id: int,
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER)),
    db: Session = Depends(get_db),
):
    service = _ensure_service(db, service_id)
    tenant = get_or_create_tenant(db, service.tenant)

    service.provision_status = "in_progress"
    service.provision_detail = "Provisioning started"
    tenant.status = "in_progress"
    tenant.detail = "Provisioning started"

    request = ProvisionRequestModel(
        service_id=service.id,
        tenant=service.tenant,
        action="provision",
        status="queued",
        detail="Provisioning request queued",
    )
    db.add(request)
    db.commit()

    detail = "Provisioning queued"
    status = "queued"
    execution_arn = None
    if STEP_FUNCTION_ARN:
        try:
            execution_arn = start_step_function_execution(service, tenant)
            request.execution_arn = execution_arn
            detail = "Provisioning started via Step Functions"
            status = "in_progress"
        except Exception as exc:  # pragma: no cover - integration path
            service.provision_status = "failed"
            service.provision_detail = f"Provisioning failed to start: {exc}"
            tenant.status = "failed"
            tenant.detail = "Provisioning failed to start"
            request.status = "failed"
            request.detail = "Step Functions start failed"
            db.commit()
            return ActionResponse(
                service_id=service_id,
                action="provision",
                status="failed",
                detail="Failed to start provisioning workflow",
            )
    else:
        detail = "Provisioning queued (Step Functions not configured)"

    service.provision_status = "in_progress"
    service.provision_detail = detail
    request.status = status
    request.detail = detail
    db.commit()
    return ActionResponse(
        service_id=service_id,
        action="provision",
        status=status,
        detail=detail,
    )


@router.get("/services/{service_id}/actions/status", response_model=StatusResponse)
def view_status(
    service_id: int,
    environment: str | None = None,
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER)),
    db: Session = Depends(get_db),
):
    service = _ensure_service(db, service_id)
    env_detail = environment or "default"
    return StatusResponse(
        service_id=service_id,
        environment=environment,
        status=service.provision_status,
        detail=service.provision_detail or f"Service healthy in {env_detail}",
    )


@router.post("/provisioning/callback")
def provisioning_callback(payload: ProvisionCallback, request: Request, db: Session = Depends(get_db)):
    token = request.headers.get("X-Callback-Token")
    if token != CALLBACK_TOKEN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid callback token")

    service = db.get(ServiceModel, payload.service_id)
    if not service:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")

    tenant = db.query(TenantModel).filter(TenantModel.name == payload.tenant).first()
    if not tenant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found")

    service.provision_status = payload.status
    service.provision_detail = payload.detail
    tenant.status = payload.status
    tenant.detail = payload.detail

    request_row = (
        db.query(ProvisionRequestModel)
        .filter(
            ProvisionRequestModel.service_id == payload.service_id,
            ProvisionRequestModel.tenant == payload.tenant,
            ProvisionRequestModel.action == "provision",
        )
        .order_by(ProvisionRequestModel.id.desc())
        .first()
    )
    if request_row:
        request_row.status = payload.status
        request_row.detail = payload.detail
        if payload.execution_arn:
            request_row.execution_arn = payload.execution_arn

    db.commit()
    return {"status": "ok"}
