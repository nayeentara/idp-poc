#!/usr/bin/env bash
set -euo pipefail

: "${TENANT_NAME:?TENANT_NAME is required}"
: "${NAMESPACE:?NAMESPACE is required}"
: "${RDS_SCHEMA:?RDS_SCHEMA is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${PROVISIONING_API_URL:?PROVISIONING_API_URL is required}"
: "${PROVISIONING_CALLBACK_TOKEN:?PROVISIONING_CALLBACK_TOKEN is required}"
: "${AWS_REGION:?AWS_REGION is required}"
: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"

KUBECONFIG_PATH="${TF_VAR_kubeconfig_path:-/tmp/kubeconfig}"
aws eks update-kubeconfig \
  --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --kubeconfig "$KUBECONFIG_PATH"

export TF_VAR_kubeconfig_path="$KUBECONFIG_PATH"

create_s3_bucket=true
create_tenant_secret=true
create_tenant_role=true
create_tenant_schema=true

if aws s3api head-bucket --bucket "$S3_BUCKET" >/dev/null 2>&1; then
  create_s3_bucket=false
fi

tenant_secret_name="idp/${TENANT_NAME}/db"
if aws secretsmanager describe-secret --secret-id "$tenant_secret_name" --region "$AWS_REGION" >/dev/null 2>&1; then
  create_tenant_secret=false
fi

PG_URI="host=${TF_VAR_db_host} port=${TF_VAR_db_port:-5432} dbname=${TF_VAR_db_name} user=${TF_VAR_db_admin_user} sslmode=require"
if PGPASSWORD="${TF_VAR_db_admin_password}" psql "$PG_URI" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${TENANT_NAME}_rw'" | grep -q 1; then
  create_tenant_role=false
fi

if PGPASSWORD="${TF_VAR_db_admin_password}" psql "$PG_URI" -tAc "SELECT 1 FROM information_schema.schemata WHERE schema_name='${RDS_SCHEMA}'" | grep -q 1; then
  create_tenant_schema=false
fi

WORKDIR=/workspace/terraform
cd "$WORKDIR"

terraform init -input=false
terraform apply -auto-approve \
  -var "tenant_name=$TENANT_NAME" \
  -var "namespace=$NAMESPACE" \
  -var "rds_schema=$RDS_SCHEMA" \
  -var "s3_bucket=$S3_BUCKET" \
  -var "create_s3_bucket=$create_s3_bucket" \
  -var "create_tenant_secret=$create_tenant_secret" \
  -var "create_tenant_role=$create_tenant_role" \
  -var "create_tenant_schema=$create_tenant_schema"

payload=$(jq -n \
  --arg tenant "$TENANT_NAME" \
  --arg status "succeeded" \
  --arg detail "Provisioning complete" \
  --argjson service_id "${SERVICE_ID:-0}" \
  '{tenant: $tenant, status: $status, detail: $detail, service_id: $service_id}')

curl -sS -X POST "$PROVISIONING_API_URL/provisioning/callback" \
  -H "Content-Type: application/json" \
  -H "X-Callback-Token: $PROVISIONING_CALLBACK_TOKEN" \
  -d "$payload"
