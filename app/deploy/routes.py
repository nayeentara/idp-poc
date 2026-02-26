import json

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.auth.utils import ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER, require_roles
from app.core.config import AWS_REGION, DEPLOYMENT_CALLBACK_TOKEN, DEPLOY_STEP_FUNCTION_ARN
from app.core.deps import get_db
from app.deploy.models import DeploymentModel
from app.deploy.schemas import DeployCallback, DeployRequest, DeployResponse, DeployStatusResponse
from app.services.models import ServiceModel

try:
    import boto3
except Exception:  # pragma: no cover - optional dependency for Step Functions
    boto3 = None

router = APIRouter(prefix="/services", tags=["deploy"])


def _ensure_service(db: Session, service_id: int) -> ServiceModel:
    service = db.get(ServiceModel, service_id)
    if not service:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    return service


def _resolve_environment(service: ServiceModel, requested_env: str | None) -> str:
    envs = service.environments or []
    if requested_env:
        if requested_env not in envs:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Environment '{requested_env}' is not enabled for this service")
        return requested_env
    return envs[0] if envs else "dev"


def _start_deploy_execution(service: ServiceModel, deployment: DeploymentModel) -> str | None:
    if not DEPLOY_STEP_FUNCTION_ARN:
        return None
    if not boto3:
        raise RuntimeError("boto3 not installed")
    client = boto3.client("stepfunctions", region_name=AWS_REGION)
    execution_input = {
        "deployment_id": deployment.id,
        "service": {
            "id": service.id,
            "name": service.name,
            "tenant": service.tenant,
            "repo_url": service.repo_url,
            "owner_team": service.owner_team,
            "runtime": service.runtime,
            "tier": service.tier,
        },
        "environment": deployment.environment,
    }
    resp = client.start_execution(stateMachineArn=DEPLOY_STEP_FUNCTION_ARN, input=json.dumps(execution_input))
    return resp.get("executionArn")


def _sync_deployment_status_from_step_functions(deployment: DeploymentModel, db: Session) -> None:
    if deployment.status not in {"queued", "in_progress"}:
        return
    if not deployment.execution_arn or not boto3:
        return
    try:
        client = boto3.client("stepfunctions", region_name=AWS_REGION)
        resp = client.describe_execution(executionArn=deployment.execution_arn)
    except Exception:
        return

    sf_status = resp.get("status", "")
    if sf_status == "RUNNING":
        return
    if sf_status == "SUCCEEDED":
        deployment.status = "succeeded"
        if deployment.detail in {"Deployment request queued", "Deployment started via Step Functions"}:
            deployment.detail = "Deployment succeeded"
    elif sf_status in {"FAILED", "TIMED_OUT", "ABORTED"}:
        deployment.status = "failed"
        failure_detail = resp.get("error") or sf_status
        cause = resp.get("cause")
        if cause:
            failure_detail = f"{failure_detail}: {cause}"
        deployment.detail = f"Deployment failed: {failure_detail}"
    db.commit()


@router.post("/{service_id}/actions/deploy", response_model=DeployResponse)
def deploy(
    service_id: int,
    payload: DeployRequest | None = None,
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER)),
    db: Session = Depends(get_db),
):
    service = _ensure_service(db, service_id)
    requested_env = payload.environment if payload else None
    env = _resolve_environment(service, requested_env)

    deployment = DeploymentModel(
        service_id=service_id,
        environment=env,
        status="queued",
        detail="Deployment request queued",
    )
    db.add(deployment)
    db.commit()
    db.refresh(deployment)

    try:
        execution_arn = _start_deploy_execution(service, deployment)
        if execution_arn:
            deployment.execution_arn = execution_arn
            deployment.status = "in_progress"
            deployment.detail = "Deployment started via Step Functions"
        else:
            deployment.detail = "Deployment queued (Step Functions not configured)"
        db.commit()
    except Exception as exc:  # pragma: no cover - integration path
        deployment.status = "failed"
        deployment.detail = f"Deployment failed to start: {exc}"
        db.commit()
        return DeployResponse(
            deployment_id=deployment.id,
            service_id=service_id,
            environment=env,
            action="deploy",
            status="failed",
            detail="Failed to start deployment workflow",
        )

    return DeployResponse(
        deployment_id=deployment.id,
        service_id=service_id,
        environment=env,
        action="deploy",
        status=deployment.status,
        detail=deployment.detail,
        execution_arn=deployment.execution_arn,
    )


@router.get("/{service_id}/actions/deploy/status", response_model=DeployStatusResponse)
def deploy_status(
    service_id: int,
    _: str = Depends(require_roles(ROLE_ADMIN, ROLE_DEVELOPER, ROLE_VIEWER)),
    db: Session = Depends(get_db),
):
    _ensure_service(db, service_id)
    deployment = (
        db.query(DeploymentModel)
        .filter(DeploymentModel.service_id == service_id)
        .order_by(DeploymentModel.id.desc())
        .first()
    )
    if not deployment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No deployment found for service")
    _sync_deployment_status_from_step_functions(deployment, db)
    db.refresh(deployment)
    return DeployStatusResponse(
        deployment_id=deployment.id,
        service_id=deployment.service_id,
        environment=deployment.environment,
        status=deployment.status,
        detail=deployment.detail,
        execution_arn=deployment.execution_arn,
    )


@router.post("/deployments/callback")
def deployment_callback(payload: DeployCallback, request: Request, db: Session = Depends(get_db)):
    token = request.headers.get("X-Callback-Token")
    if token != DEPLOYMENT_CALLBACK_TOKEN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid callback token")

    deployment = db.get(DeploymentModel, payload.deployment_id)
    if not deployment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deployment not found")

    deployment.status = payload.status
    deployment.detail = payload.detail
    if payload.execution_arn:
        deployment.execution_arn = payload.execution_arn
    db.commit()
    return {"status": "ok"}
