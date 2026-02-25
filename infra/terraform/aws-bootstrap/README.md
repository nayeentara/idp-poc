# AWS Bootstrap (us-east-1)

This Terraform stack creates the baseline AWS resources for the IDP POC:
- VPC + subnets + NAT
- EKS cluster + managed node group
- RDS Postgres (smallest)
- ECR repo for the provisioning worker
- ECS Fargate cluster + task definition for the provisioning worker
- (Optional) S3 + DynamoDB for Terraform state backend

## Prereqs
- Terraform >= 1.5
- AWS credentials in your shell

## Quickstart
```bash
cd infra/terraform/aws-bootstrap
export TF_VAR_rds_password='CHANGEME-STRONG-PASSWORD'
terraform init
terraform apply
```

## Destroy
```bash
terraform destroy
```

## Notes
- This uses `db.t4g.micro` which is low-cost but not always free tier.
- The ECS task definition uses the ECR repo `:latest` tag; push your worker image there.
- EKS cluster endpoint is public+private for simplicity.

If you want tighter security or production defaults, say the word.
