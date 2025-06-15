# Domain 1: Design Solutions for Organizational Complexity (26%)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d1"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# AWS Organizations Setup (if enabled)
resource "aws_organizations_organization" "main" {
  count = var.enable_organizations ? 1 : 0

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com"
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  feature_set = "ALL"
}

# Transit Gateway for multi-account networking
resource "aws_ec2_transit_gateway" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  description                     = "${local.name_prefix} Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-tgw"
      Domain = "1"
    }
  )
}

# Cross-account IAM role
resource "aws_iam_role" "cross_account_admin" {
  name = "${local.name_prefix}-cross-account-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_ids
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-cross-account-admin"
      Domain = "1"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cross_account_admin" {
  role       = aws_iam_role.cross_account_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Centralized logging bucket
resource "aws_s3_bucket" "centralized_logs" {
  bucket = "${local.name_prefix}-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-centralized-logs"
      Domain = "1"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "centralized_logs" {
  bucket = aws_s3_bucket.centralized_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS Config for compliance
resource "aws_config_configuration_recorder" "main" {
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "${local.name_prefix}-config-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-config"
      Domain = "1"
    }
  )
}

resource "aws_iam_role" "config" {
  name = "${local.name_prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Cost allocation tags
resource "aws_ce_cost_category" "departments" {
  rule_version = "CostCategoryExpression.v1"
  name = "${local.name_prefix}-departments"

  rule {
    value = "Engineering"
    rule {
      tags {
        key    = "Department"
        values = ["Engineering", "DevOps"]
      }
    }
  }

  rule {
    value = "Other"
    rule {
      not {
        tags {
          key    = "Department"
          values = ["Engineering", "DevOps"]
        }
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-cost-categories"
      Domain = "1"
    }
  )
}
