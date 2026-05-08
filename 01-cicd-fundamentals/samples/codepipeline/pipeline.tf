terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "devops-platform"
}

variable "github_repo" {
  type        = string
  description = "owner/repo (e.g. your-handle/aws-devops-platform)"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "codestar_connection_arn" {
  type        = string
  description = "ARN of an existing CodeStar Connection to GitHub (create once via console)"
}

data "aws_caller_identity" "current" {}
data "aws_ecr_repository" "app" { name = "${var.project_name}-app" }
data "aws_ecs_cluster" "this"   { cluster_name = "${var.project_name}-cluster" }

# --- Artifact bucket ---------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.project_name}-artifacts-"
  force_destroy = true
}

# --- IAM ---------------------------------------------------------------------
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:*"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:*"], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"] },
      { Effect = "Allow", Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ], Resource = "*" },
    ]
  })
}

resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:*"], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"] },
      { Effect = "Allow", Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"], Resource = "*" },
      { Effect = "Allow", Action = ["codestar-connections:UseConnection"], Resource = var.codestar_connection_arn },
      { Effect = "Allow", Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "iam:PassRole"
        ], Resource = "*" },
    ]
  })
}

# --- CodeBuild project -------------------------------------------------------
resource "aws_codebuild_project" "build" {
  name         = "${var.project_name}-build"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  source {
    type      = "CODEPIPELINE"
    buildspec = "samples/codepipeline/buildspec.yml"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
    environment_variable {
      name  = "ECR_REGISTRY"
      value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
    }
    environment_variable {
      name  = "ECR_REPOSITORY"
      value = data.aws_ecr_repository.app.repository_url
    }
  }
}

# --- Pipeline ----------------------------------------------------------------
resource "aws_codepipeline" "this" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]
      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["build"]
      configuration    = { ProjectName = aws_codebuild_project.build.name }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build"]
      configuration = {
        ClusterName = data.aws_ecs_cluster.this.cluster_name
        ServiceName = "${var.project_name}-svc"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
