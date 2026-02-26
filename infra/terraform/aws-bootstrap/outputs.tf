output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca" {
  value = module.eks.cluster_certificate_authority_data
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}

output "rds_db_name" {
  value = var.rds_db_name
}

output "ecr_repo" {
  value = aws_ecr_repository.provisioner.repository_url
}

output "app_ecr_repo" {
  value = aws_ecr_repository.app.repository_url
}

output "deployer_ecr_repo" {
  value = aws_ecr_repository.deployer.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.provisioner.name
}

output "ecs_task_definition" {
  value = aws_ecs_task_definition.provisioner.arn
}

output "app_ecs_service" {
  value = aws_ecs_service.app.name
}

output "app_ecs_task_definition" {
  value = aws_ecs_task_definition.app.arn
}

output "deployer_ecs_task_definition" {
  value = aws_ecs_task_definition.deployer.arn
}

output "app_alb_dns" {
  value = aws_lb.app.dns_name
}

output "managed_observability_enabled" {
  value = var.enable_managed_observability
}

output "managed_prometheus_workspace_id" {
  value = try(aws_prometheus_workspace.observability[0].id, null)
}

output "managed_prometheus_workspace_arn" {
  value = try(aws_prometheus_workspace.observability[0].arn, null)
}

output "managed_prometheus_endpoint" {
  value = try(aws_prometheus_workspace.observability[0].prometheus_endpoint, null)
}

output "managed_grafana_workspace_id" {
  value = try(aws_grafana_workspace.observability[0].id, null)
}

output "managed_grafana_workspace_url" {
  value = try("https://${aws_grafana_workspace.observability[0].endpoint}", null)
}

output "tf_state_bucket" {
  value       = try(aws_s3_bucket.tf_state[0].bucket, null)
  description = "Terraform state bucket (if created)"
}

output "tf_lock_table" {
  value       = try(aws_dynamodb_table.tf_lock[0].name, null)
  description = "Terraform lock table (if created)"
}
