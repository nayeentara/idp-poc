output "namespace" {
  value = kubernetes_namespace.tenant.metadata[0].name
}

output "rds_schema" {
  value = postgresql_schema.tenant.name
}

output "s3_bucket" {
  value = aws_s3_bucket.tenant.bucket
}

output "secret_arn" {
  value = aws_secretsmanager_secret.tenant_db.arn
}
