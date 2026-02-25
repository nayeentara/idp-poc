variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "idp-poc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.128.0/20", "10.20.144.0/20", "10.20.160.0/20"]
}

variable "eks_version" {
  type    = string
  default = "1.29"
}

variable "eks_node_instance_type" {
  type    = string
  default = "t3.small"
}

variable "eks_node_desired" {
  type    = number
  default = 1
}

variable "eks_node_min" {
  type    = number
  default = 1
}

variable "eks_node_max" {
  type    = number
  default = 2
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_db_name" {
  type    = string
  default = "idp_shared"
}

variable "rds_username" {
  type    = string
  default = "idp_admin"
}

variable "rds_password" {
  type      = string
  sensitive = true
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "create_state_backend" {
  type    = bool
  default = true
}
