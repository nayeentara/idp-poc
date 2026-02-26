# AWS Bootstrap (us-east-1)

This Terraform stack creates the baseline AWS resources for the IDP POC:
- VPC + subnets + NAT
- EKS cluster + managed node group
- RDS Postgres (smallest)
- ECR repos for the provisioning worker and app
- ECS Fargate cluster + task definitions + app service + ALB
- (Optional) S3 + DynamoDB for Terraform state backend

## Prereqs
- Terraform >= 1.5
- AWS credentials in your shell

## Quickstart
```bash
cd infra/terraform/aws-bootstrap
export TF_VAR_rds_password='CHANGEME-STRONG-PASSWORD'
export TF_VAR_app_jwt_secret='CHANGEME-JWT-SECRET'
export TF_VAR_app_callback_token='CHANGEME-CALLBACK-TOKEN'
export TF_VAR_app_step_function_arn='OPTIONAL-STEP-FUNCTION-ARN'
export TF_VAR_app_deploy_step_function_arn='OPTIONAL-DEPLOY-STEP-FUNCTION-ARN'
terraform init
terraform apply
```

## Destroy
```bash
terraform destroy
```

## Notes
- This uses `db.t4g.micro` which is low-cost but not always free tier.
- The ECS task definitions use the ECR repos with `:latest` tag; push images there.
- EKS cluster endpoint is public+private for simplicity.

If you want tighter security or production defaults, say the word.
