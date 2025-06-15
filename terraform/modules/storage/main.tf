locals {
  common_name = "${var.project_name}-${var.environment}"
}

resource "aws_s3_bucket" "main" {
  provider = aws.primary
  bucket   = "${local.common_name}-lab-${random_string.lab_bucket_suffix[0].result}"

  tags = merge(var.common_tags, {
    Name = "${local.common_name}-lab-bucket"
  })
}

resource "random_string" "bucket_suffix" {
  count   = 1
  length  = 8
  special = false
  upper   = false
}
