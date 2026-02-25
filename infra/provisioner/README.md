# Provisioner Worker

This worker runs Terraform to provision tenant-scoped resources and calls back to the API when finished.

## Inputs (env)
- `TENANT_NAME`
- `NAMESPACE`
- `RDS_SCHEMA`
- `S3_BUCKET`
- `SERVICE_ID` (optional)
- `PROVISIONING_API_URL`
- `PROVISIONING_CALLBACK_TOKEN`
- Terraform vars for DB/Kubernetes:
  - `TF_VAR_db_host`
  - `TF_VAR_db_name`
  - `TF_VAR_db_admin_user`
  - `TF_VAR_db_admin_password`
  - `TF_VAR_tenant_db_password`
  - `TF_VAR_kubeconfig_path`
  - `TF_VAR_aws_region`

## Notes
- In production, run this as an ECS task or EKS job triggered by Step Functions.
- The API callback updates service and tenant provisioning status.
