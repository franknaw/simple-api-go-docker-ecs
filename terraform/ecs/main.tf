terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.54"
    }
  }
}

provider "aws" {
  region = local.region
  assume_role {
    role_arn     = "arn:aws-us-gov:iam::${local.account}:role/SOME_Administrator"
    session_name = "terraform"
  }
}

locals {
  account     = "123456"
  region      = "us-gov-west-1"
  environment = "test"
  app_name    = "test-api"
}


/**
* Retrieve VPC and Private Subnet
*/

data "aws_vpc" "gateway-vpc" {
  filter {
    name = "tag:Name"
    values = [
    "GATEWAY-VPC"]
  }
}

data "aws_subnet_ids" "gateway-subs" {
  vpc_id = data.aws_vpc.gateway-vpc.id
}

data "aws_subnet" "gateway-sub-private-1a" {
  filter {
    name   = "tag:Name"
    values = ["GATEWAY-Private-Subnet-1"]
  }
}

/**
*  Setup Security Group for ECS Network
*/

resource "aws_security_group" "sg" {
  vpc_id = data.aws_vpc.gateway-vpc.id
  name   = "${local.app_name}-ecs-sg"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  tags = {
    "Name"        = "${local.app_name}-ecs-sg"
    "Environment" = local.environment
  }
}

/**
*  Define a ECS Cluster
*/

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${local.app_name}-cluster"

  tags = {
    Name = "${local.app_name}-cluster"
  }
}

/**
*  Retrieve ECR - defined in ecr/main.tf
*/

data "aws_ecr_repository" "repo" {
  name = local.app_name
}

output "repo" {
  value = data.aws_ecr_repository.repo.repository_url
}

/**
*  Retrieve ECR Image - The image pushed in to the ECR
*/

data "aws_ecr_image" "image" {
  repository_name = data.aws_ecr_repository.repo.name
  image_tag       = "latest"
}

output "image" {
  value = data.aws_ecr_image.image.image_digest
}

/**
*  Retrieve ECS task execution role
   This role will need to be created.
*/

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ECSTaskExecutionRole"
}

output "task_role" {
  value = data.aws_iam_role.ecs_task_execution_role
}

/**
*  Define ECS for test-api
*/

resource "aws_ecs_service" "service" {
  name            = "${local.app_name}-service"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [data.aws_subnet.gateway-sub-private-1a.id]
    assign_public_ip = false
    security_groups  = [aws_security_group.sg.id]
  }
  desired_count = 1

  // Attached to Target group in ALB - beyond the scope of the simeple demo
  #  load_balancer {
  #    target_group_arn = "arn:aws-us-gov:elasticloadbalancing:us-gov-west-1:1111:targetgroup/test-api/1111"
  #    container_name   = local.app_name
  #    container_port   = 8080
  #  }

  tags = {
    "Name"        = "${local.app_name}-service"
    "Environment" = local.environment
  }
}

/**
*  Define ECS Task for test-api
*/

resource "aws_ecs_task_definition" "task" {
  family       = local.app_name
  network_mode = "awsvpc"
  requires_compatibilities = [
  "FARGATE"]
  cpu                = 4096
  memory             = 12288
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = data.aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = local.app_name
      image     = "${data.aws_ecr_repository.repo.repository_url}:${data.aws_ecr_image.image.image_tag}@${data.aws_ecr_image.image.image_digest}"
      cpu       = 3000
      memory    = 12288
      essential = true
      cpuUnits  = 3000
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SOME_PROP"
          value = "SOME VALUE"
        }
      ]
      ulimits = [
        {
          name      = "memlock"
          softLimit = 4000
          hardLimit = 10000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.app_name}"
          awslogs-region        = "us-gov-west-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    "Name"        = "${local.app_name}-task"
    "Environment" = local.environment
  }
}

/*
  This needs to be created in IAM.  TODO programmatically generate it.
  Role: ECSTaskExecutionRole  - select trusted entity ECS
    AWS managed policy: AmazonElasticFileSystemFullAccess
    AWS managed policy: EC2InstanceProfileForImageBuilderECRContainerBuilds
    AWS managed policy: SecretsManagerReadWrite
    AWS managed policy: CloudWatchLogsFullAccess
    AWS managed policy: AmazonECSTaskExecutionRolePolicy
    AWS managed policy: AmazonECS_FullAccess
    AWS managed policy: AmazonS3FullAccess
*/
