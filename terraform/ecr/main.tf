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
* Create ECR for test api
*/

resource "aws_ecr_repository" "repo" {
  name                 = local.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name        = "${local.app_name}-repo",
    Environment = local.environment
  }
}

resource "aws_ecr_repository_policy" "policy-resources" {
  repository = aws_ecr_repository.repo.name
  policy     = var.repo-policy
}

variable "repo-policy" {
  default = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "ECR Repository Policy",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages",
                "ecr:DeleteRepository",
                "ecr:BatchDeleteImage",
                "ecr:SetRepositoryPolicy",
                "ecr:DeleteRepositoryPolicy"
            ]
        }
    ]
}
EOF
}
