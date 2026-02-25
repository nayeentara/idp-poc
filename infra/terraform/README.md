# Terraform Provisioning (Tenant Scoped)

This folder is a placeholder for the Terraform code that provisions tenant-scoped resources:
- EKS namespace: `tenant-<slug>`
- RDS schema: `tenant_<slug>` and role `tenant_<slug>_rw`
- S3 bucket: `idp-tenant-<slug>`
- Secrets Manager entry with DB connection info

## Expected Inputs
- `tenant_name`
- `namespace`
- `rds_schema`
- `s3_bucket`

## Expected Outputs
- `namespace`
- `rds_schema`
- `s3_bucket`
- `secret_arn`

Implementers typically wire this into a Step Functions task that runs Terraform in a worker (ECS/EKS).
