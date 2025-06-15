# Domain 4: Accelerate Workload Migration and Modernization (20%)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d4"
}

# S3 Bucket for Migration Data
resource "aws_s3_bucket" "migration_data" {
  bucket = "${local.name_prefix}-migration-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-migration-data"
      Domain = "4"
    }
  )
}

data "aws_caller_identity" "current" {}
