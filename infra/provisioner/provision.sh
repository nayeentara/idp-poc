#!/usr/bin/env bash
set -euo pipefail

ACTION="${ACTION:-provision}"
KUBECONFIG_PATH="${TF_VAR_kubeconfig_path:-/tmp/kubeconfig}"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

send_callback() {
  local status="$1"
  local detail="$2"
  local action_name="$3"
  payload=$(jq -n \
    --arg tenant "$TENANT_NAME" \
    --arg action "$action_name" \
    --arg status "$status" \
    --arg detail "$detail" \
    --argjson service_id "${SERVICE_ID:-0}" \
    '{tenant: $tenant, action: $action, status: $status, detail: $detail, service_id: $service_id}')
  curl -sS -X POST "$PROVISIONING_API_URL/provisioning/callback" \
    -H "Content-Type: application/json" \
    -H "X-Callback-Token: $PROVISIONING_CALLBACK_TOKEN" \
    -d "$payload"
}

require_var AWS_REGION
require_var EKS_CLUSTER_NAME
require_var TENANT_NAME
require_var NAMESPACE
require_var RDS_SCHEMA
require_var S3_BUCKET
require_var PROVISIONING_API_URL
require_var PROVISIONING_CALLBACK_TOKEN
require_var TF_VAR_db_host
require_var TF_VAR_db_name
require_var TF_VAR_db_admin_user
require_var TF_VAR_db_admin_password

aws eks update-kubeconfig \
  --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --kubeconfig "$KUBECONFIG_PATH"
export TF_VAR_kubeconfig_path="$KUBECONFIG_PATH"

create_s3_bucket=true
create_tenant_secret=true
create_tenant_role=true
create_tenant_schema=true
create_namespace=true

if kubectl --kubeconfig "$KUBECONFIG_PATH" get namespace "$NAMESPACE" >/dev/null 2>&1; then
  create_namespace=false
fi

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

cd /workspace/terraform

if [ "$ACTION" = "deprovision" ]; then
  kubectl --kubeconfig "$KUBECONFIG_PATH" delete namespace "$NAMESPACE" --ignore-not-found=true || true
  aws s3 rb "s3://$S3_BUCKET" --force || true

  role_name="${TENANT_NAME}_rw"
  PGPASSWORD="${TF_VAR_db_admin_password}" psql "$PG_URI" -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = '${RDS_SCHEMA}') THEN
    EXECUTE format('ALTER SCHEMA %I OWNER TO %I', '${RDS_SCHEMA}', '${TF_VAR_db_admin_user}');
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${role_name}') THEN
    EXECUTE format('REASSIGN OWNED BY %I TO %I', '${role_name}', '${TF_VAR_db_admin_user}');
    EXECUTE format('DROP OWNED BY %I', '${role_name}');
    EXECUTE format('DROP ROLE %I', '${role_name}');
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = '${RDS_SCHEMA}') THEN
    EXECUTE format('DROP SCHEMA %I CASCADE', '${RDS_SCHEMA}');
  END IF;
END
\$\$;
SQL

  aws secretsmanager delete-secret \
    --secret-id "idp/${TENANT_NAME}/db" \
    --force-delete-without-recovery \
    --region "$AWS_REGION" || true

  send_callback "succeeded" "Deprovisioning complete" "deprovision"
else
  terraform init -input=false
  terraform apply -auto-approve \
    -var "tenant_name=$TENANT_NAME" \
    -var "namespace=$NAMESPACE" \
    -var "rds_schema=$RDS_SCHEMA" \
    -var "s3_bucket=$S3_BUCKET" \
    -var "create_namespace=$create_namespace" \
    -var "create_s3_bucket=$create_s3_bucket" \
    -var "create_tenant_secret=$create_tenant_secret" \
    -var "create_tenant_role=$create_tenant_role" \
    -var "create_tenant_schema=$create_tenant_schema"

  send_callback "succeeded" "Provisioning complete" "provision"
fi
