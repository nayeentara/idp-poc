import json
import re
import secrets
from typing import Optional

from app.core.config import AWS_REGION, DEFAULT_BUCKET_PREFIX, STEP_FUNCTION_ARN
from app.provisioning.models import TenantModel
from app.services.models import ServiceModel

try:
    import boto3
except Exception:  # pragma: no cover - optional dependency for Step Functions
    boto3 = None


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower())
    return slug.strip("-") or "tenant"


def generate_tenant_db_password() -> str:
    # URL-safe token avoids shell/JSON escaping issues when passed through env vars.
    return secrets.token_urlsafe(24)


def get_or_create_tenant(db, tenant_name: str) -> TenantModel:
    tenant = db.query(TenantModel).filter(TenantModel.name == tenant_name).first()
    if tenant:
        return tenant
    slug = slugify(tenant_name)
    tenant = TenantModel(
        name=tenant_name,
        status="not_requested",
        detail="",
        namespace=f"tenant-{slug}",
        rds_schema=f"tenant_{slug}",
        s3_bucket=f"{DEFAULT_BUCKET_PREFIX}-{slug}",
    )
    db.add(tenant)
    db.commit()
    db.refresh(tenant)
    return tenant


def start_step_function_execution(service: ServiceModel, tenant: TenantModel, action: str = "provision") -> Optional[str]:
    if not STEP_FUNCTION_ARN:
        return None
    if not boto3:
        raise RuntimeError("boto3 not installed")

    client = boto3.client("stepfunctions", region_name=AWS_REGION)
    tenant_payload = {
        "name": tenant.name,
        "namespace": tenant.namespace,
        "rds_schema": tenant.rds_schema,
        "s3_bucket": tenant.s3_bucket,
    }
    if action == "provision":
        tenant_payload["db_password"] = generate_tenant_db_password()

    execution_input = {
        "action": action,
        "tenant": {
            **tenant_payload,
        },
        "service": {
            "id": service.id,
            "name": service.name,
            "repo_url": service.repo_url,
            "owner_team": service.owner_team,
            "runtime": service.runtime,
            "tier": service.tier,
            "environments": service.environments,
        },
    }
    resp = client.start_execution(stateMachineArn=STEP_FUNCTION_ARN, input=json.dumps(execution_input))
    return resp.get("executionArn")
