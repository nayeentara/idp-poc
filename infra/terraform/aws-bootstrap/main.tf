locals {
  name = var.name_prefix
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.1"

  cluster_name    = "${local.name}-eks"
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      instance_types = [var.eks_node_instance_type]
      desired_size   = var.eks_node_desired
      min_size       = var.eks_node_min
      max_size       = var.eks_node_max
    }
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Allow Postgres from EKS and ECS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds" {
  name       = "${local.name}-rds-subnets"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "postgres" {
  identifier             = "${local.name}-postgres"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  username               = var.rds_username
  password               = var.rds_password
  db_name                = var.rds_db_name
  skip_final_snapshot    = true
  publicly_accessible    = false
}

resource "aws_ecr_repository" "provisioner" {
  name = "${local.name}-provisioner"
}

resource "aws_ecs_cluster" "provisioner" {
  name = "${local.name}-provisioner"
}

resource "aws_cloudwatch_log_group" "provisioner" {
  name              = "/ecs/${local.name}-provisioner"
  retention_in_days = 14
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name}-ecs-task-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name}-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_permissions" {
  name = "${local.name}-ecs-task-permissions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret",
          "s3:CreateBucket",
          "s3:PutBucketTagging",
          "s3:PutBucketEncryption",
          "s3:PutBucketVersioning",
          "rds:DescribeDBInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_permissions" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_task_permissions.arn
}

resource "aws_ecs_task_definition" "provisioner" {
  family                   = "${local.name}-provisioner"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn
  task_role_arn             = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "terraform",
      image     = "${aws_ecr_repository.provisioner.repository_url}:latest",
      essential = true,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.provisioner.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      },
      environment = [
        { name = "TF_VAR_db_host", value = aws_db_instance.postgres.address },
        { name = "TF_VAR_db_name", value = var.rds_db_name },
        { name = "TF_VAR_db_admin_user", value = var.rds_username },
        { name = "TF_VAR_db_admin_password", value = var.rds_password },
        { name = "TF_VAR_aws_region", value = var.aws_region }
      ]
    }
  ])
}

resource "aws_s3_bucket" "tf_state" {
  count  = var.create_state_backend ? 1 : 0
  bucket = "${local.name}-tf-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_dynamodb_table" "tf_lock" {
  count        = var.create_state_backend ? 1 : 0
  name         = "${local.name}-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_caller_identity" "current" {}
