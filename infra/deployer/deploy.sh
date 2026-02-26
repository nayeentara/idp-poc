#!/usr/bin/env bash
set -euo pipefail

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

send_deploy_callback() {
  local status="$1"
  local detail="$2"
  payload=$(jq -n \
    --arg status "$status" \
    --arg detail "$detail" \
    --argjson deployment_id "${DEPLOYMENT_ID}" \
    '{deployment_id: $deployment_id, status: $status, detail: $detail}')
  curl -sS -X POST "$DEPLOYMENT_API_URL/services/deployments/callback" \
    -H "Content-Type: application/json" \
    -H "X-Callback-Token: $DEPLOYMENT_CALLBACK_TOKEN" \
    -d "$payload"
}

require_var AWS_REGION
require_var EKS_CLUSTER_NAME
require_var DEPLOYMENT_ID
require_var DEPLOYMENT_API_URL
require_var DEPLOYMENT_CALLBACK_TOKEN
require_var SERVICE_NAME
require_var TARGET_ENV

KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/kubeconfig}"
aws eks update-kubeconfig \
  --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --kubeconfig "$KUBECONFIG_PATH"

trap 'send_deploy_callback "failed" "Deploy runner failed"' ERR

namespace="${NAMESPACE:-tenant-${TENANT_NAME:-}}"
if [ -z "$namespace" ] || [ "$namespace" = "tenant-" ]; then
  echo "Missing namespace context for deploy (set NAMESPACE or TENANT_NAME)" >&2
  exit 1
fi
if ! kubectl --kubeconfig "$KUBECONFIG_PATH" get namespace "$namespace" >/dev/null 2>&1; then
  echo "Namespace $namespace does not exist" >&2
  exit 1
fi

k8s_name="$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')"
if [ -z "$k8s_name" ]; then
  echo "SERVICE_NAME cannot be transformed into valid Kubernetes name" >&2
  exit 1
fi

image_tag="${IMAGE_TAG:-latest}"
if [ -n "${SERVICE_IMAGE:-}" ]; then
  image="$SERVICE_IMAGE"
else
  require_var AWS_ACCOUNT_ID
  image="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SERVICE_NAME}:${image_tag}"
fi

cat <<YAML | kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${k8s_name}
  labels:
    app: ${k8s_name}
    env: ${TARGET_ENV}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${k8s_name}
  template:
    metadata:
      labels:
        app: ${k8s_name}
        env: ${TARGET_ENV}
    spec:
      containers:
      - name: ${k8s_name}
        image: ${image}
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: ${k8s_name}
  labels:
    app: ${k8s_name}
spec:
  selector:
    app: ${k8s_name}
  ports:
  - port: 80
    targetPort: 8000
YAML

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" rollout status deployment/"$k8s_name" --timeout=180s
send_deploy_callback "succeeded" "Deployment rollout succeeded"
