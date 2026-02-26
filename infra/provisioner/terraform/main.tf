terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "postgresql" {
  host            = var.db_host
  port            = var.db_port
  database        = var.db_name
  username        = var.db_admin_user
  password        = var.db_admin_password
  superuser       = false
  sslmode         = "require"
  connect_timeout = 15
}

locals {
  tenant_role_name = "${var.tenant_name}_rw"
}

resource "kubernetes_namespace" "tenant" {
  metadata {
    name = var.namespace
    labels = {
      tenant = var.tenant_name
    }
  }
}

resource "aws_s3_bucket" "tenant" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = var.s3_bucket
}

resource "postgresql_role" "tenant_rw" {
  count    = var.create_tenant_role ? 1 : 0
  name     = local.tenant_role_name
  login    = true
  password = var.tenant_db_password
}

resource "postgresql_schema" "tenant" {
  count = var.create_tenant_schema ? 1 : 0
  name  = var.rds_schema
  owner = local.tenant_role_name
}

data "aws_secretsmanager_secret" "tenant_db" {
  count = var.create_tenant_secret ? 0 : 1
  name  = "idp/${var.tenant_name}/db"
}

resource "aws_secretsmanager_secret" "tenant_db" {
  count = var.create_tenant_secret ? 1 : 0
  name  = "idp/${var.tenant_name}/db"
}

resource "aws_secretsmanager_secret_version" "tenant_db" {
  secret_id = var.create_tenant_secret ? aws_secretsmanager_secret.tenant_db[0].id : data.aws_secretsmanager_secret.tenant_db[0].id
  secret_string = jsonencode({
    host     = var.db_host,
    port     = var.db_port,
    database = var.db_name,
    schema   = var.rds_schema,
    username = local.tenant_role_name,
    password = var.tenant_db_password
  })
}
