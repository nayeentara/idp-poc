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
  sslmode         = "require"
  connect_timeout = 15
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
  bucket = var.s3_bucket
}

resource "postgresql_role" "tenant_rw" {
  name     = "${var.tenant_name}_rw"
  login    = true
  password = var.tenant_db_password
}

resource "postgresql_schema" "tenant" {
  name  = var.rds_schema
  owner = postgresql_role.tenant_rw.name
}

resource "aws_secretsmanager_secret" "tenant_db" {
  name = "idp/${var.tenant_name}/db"
}

resource "aws_secretsmanager_secret_version" "tenant_db" {
  secret_id     = aws_secretsmanager_secret.tenant_db.id
  secret_string = jsonencode({
    host     = var.db_host,
    port     = var.db_port,
    database = var.db_name,
    schema   = var.rds_schema,
    username = postgresql_role.tenant_rw.name,
    password = var.tenant_db_password
  })
}
