# Domain 2: Design for New Solutions (29%)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# API Gateway for Microservices
resource "aws_api_gateway_rest_api" "microservices" {
  name        = "${local.name_prefix}-microservices-api"
  description = "Microservices API for Domain 2"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-microservices-api"
      Domain = "2"
    }
  )
}

# Lambda Function placeholder
resource "aws_lambda_function" "api_handler" {
  count = var.enable_lambda ? 1 : 0

  filename         = "${path.module}/lambda/placeholder.zip"
  function_name    = "${local.name_prefix}-api-handler"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-api-handler"
      Domain = "2"
    }
  )
}

# DynamoDB Table
resource "aws_dynamodb_table" "app_data" {
  name         = "${local.name_prefix}-app-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-app-data"
      Domain = "2"
    }
  )
}

# Auto Scaling Group
resource "aws_launch_template" "app" {
  count = var.enable_auto_scaling ? 1 : 0

  name_prefix   = "${local.name_prefix}-app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      {
        Name   = "${local.name_prefix}-app-instance"
        Domain = "2"
      }
    )
  }
}

resource "aws_autoscaling_group" "app" {
  count = var.enable_auto_scaling ? 1 : 0

  name               = "${local.name_prefix}-app-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size           = 1
  max_size           = 3
  desired_capacity   = 1

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Data source for AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
