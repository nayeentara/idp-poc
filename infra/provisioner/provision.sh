#!/usr/bin/env bash
set -euo pipefail

: "${TENANT_NAME:?TENANT_NAME is required}"
: "${NAMESPACE:?NAMESPACE is required}"
: "${RDS_SCHEMA:?RDS_SCHEMA is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${PROVISIONING_API_URL:?PROVISIONING_API_URL is required}"
: "${PROVISIONING_CALLBACK_TOKEN:?PROVISIONING_CALLBACK_TOKEN is required}"

WORKDIR=/workspace/terraform
cd "$WORKDIR"

terraform init -input=false
terraform apply -auto-approve \
  -var "tenant_name=$TENANT_NAME" \
  -var "namespace=$NAMESPACE" \
  -var "rds_schema=$RDS_SCHEMA" \
  -var "s3_bucket=$S3_BUCKET"

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
