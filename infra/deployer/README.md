# Deployer Worker

This worker performs service rollout to EKS and sends deployment callback updates.

## Inputs (env)
- `AWS_REGION`
- `EKS_CLUSTER_NAME`
- `DEPLOYMENT_ID`
- `DEPLOYMENT_API_URL`
- `DEPLOYMENT_CALLBACK_TOKEN`
- `SERVICE_NAME`
- `TARGET_ENV`
- `TENANT_NAME` (or explicit `NAMESPACE`)
- `AWS_ACCOUNT_ID` and optional `IMAGE_TAG` (unless `SERVICE_IMAGE` is passed directly)

## Behavior
- Builds kubeconfig for EKS.
- Applies a Deployment + Service manifest to the tenant namespace.
- Waits for rollout success.
- Calls `POST /services/deployments/callback` on success/failure.
