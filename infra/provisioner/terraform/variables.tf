variable "tenant_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "rds_schema" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "kubeconfig_path" {
  type    = string
  default = "/root/.kube/config"
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "db_admin_user" {
  type = string
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "tenant_db_password" {
  type      = string
  sensitive = true
}

variable "create_s3_bucket" {
  type    = bool
  default = true
}

variable "create_tenant_role" {
  type    = bool
  default = true
}

variable "create_tenant_schema" {
  type    = bool
  default = true
}

variable "create_tenant_secret" {
  type    = bool
  default = true
}
