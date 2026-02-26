output "namespace" {
  value = var.namespace
}

output "rds_schema" {
  value = var.rds_schema
}

output "s3_bucket" {
  value = var.s3_bucket
}

output "secret_arn" {
  value = try(
    aws_secretsmanager_secret.tenant_db[0].arn,
    data.aws_secretsmanager_secret.tenant_db[0].arn
  )
}
