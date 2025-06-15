# security.tf - Security & Identity Infrastructure for SA Pro
# Comprehensive security setup covering IAM, ACM, Config, GuardDuty, and compliance

# ================================================================
# DATA SOURCES
# ================================================================

# Available AZs for multi-AZ resources
data "aws_availability_zones" "available" {
  provider = aws.primary
  state    = "available"
}

# ================================================================
# KMS KEYS FOR SECURITY SERVICES
# ================================================================

# KMS key for security services encryption
resource "aws_kms_key" "security" {
  count                   = var.enable_security_tier ? 1 : 0
  provider                = aws.primary
  description             = "KMS key for security services encryption"
  deletion_window_in_days = var.development_mode ? 7 : 30
  enable_key_rotation     = true

  # Key policy for security services
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Config to use the key"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${local.common_name}-security-key"
    Type = "security-kms-key"
  }
}

# KMS key alias
resource "aws_kms_alias" "security" {
  count         = var.enable_security_tier ? 1 : 0
  provider      = aws.primary
  name          = "alias/${local.common_name}-security"
  target_key_id = aws_kms_key.security[0].key_id
}

# ================================================================
# IAM ACCOUNT SETTINGS
# ================================================================

# IAM account password policy
resource "aws_iam_account_password_policy" "main" {
  count                          = var.enable_security_tier && var.password_policy_enabled ? 1 : 0
  provider                       = aws.primary
  minimum_password_length        = 12
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age              = 90
  password_reuse_prevention     = 5
  hard_expiry                   = false
}

# ================================================================
# ADVANCED IAM ROLES AND POLICIES
# ================================================================

# Cross-account access role (for multi-account scenarios)
resource "aws_iam_role" "cross_account_access" {
  count    = var.enable_security_tier && var.enable_cross_account_roles ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-cross-account-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in var.trusted_account_ids :
            "arn:aws:iam::${account_id}:root"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = var.mfa_required ? "true" : "false"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.common_name}-cross-account-access"
    Type = "cross-account-role"
  }
}

# Security auditor role
resource "aws_iam_role" "security_auditor" {
  count    = var.enable_security_tier && var.enable_advanced_iam ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-security-auditor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.common_name}-security-auditor"
    Type = "security-auditor-role"
  }
}

# Security auditor policy
resource "aws_iam_role_policy" "security_auditor" {
  count    = var.enable_security_tier && var.enable_advanced_iam ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-security-auditor-policy"
  role     = aws_iam_role.security_auditor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "config:Get*",
          "config:List*",
          "config:Describe*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "cloudtrail:Describe*",
          "guardduty:Get*",
          "guardduty:List*",
          "securityhub:Get*",
          "securityhub:List*",
          "iam:Get*",
          "iam:List*",
          "kms:Describe*",
          "kms:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ================================================================
# AWS SYSTEMS MANAGER
# ================================================================

# Systems Manager parameter for database password
resource "aws_ssm_parameter" "db_password" {
  count     = var.enable_security_tier && var.enable_systems_manager ? 1 : 0
  provider  = aws.primary
  name      = "/${local.common_name}/database/master_password"
  type      = "SecureString"
  value     = var.mysql_master_password
  key_id    = aws_kms_key.security[0].arn
  overwrite = true

  tags = {
    Name        = "${local.common_name}-db-password"
    Type        = "secure-parameter"
    Environment = var.common_tags.Environment
  }
}

# Systems Manager parameter for Redis auth token
resource "aws_ssm_parameter" "redis_token" {
  count     = var.enable_security_tier && var.enable_systems_manager ? 1 : 0
  provider  = aws.primary
  name      = "/${local.common_name}/cache/redis_auth_token"
  type      = "SecureString"
  value     = var.redis_auth_token
  key_id    = aws_kms_key.security[0].arn
  overwrite = true

  tags = {
    Name        = "${local.common_name}-redis-token"
    Type        = "secure-parameter"
    Environment = var.common_tags.Environment
  }
}

# Systems Manager parameter for application configuration
resource "aws_ssm_parameter" "app_config" {
  count     = var.enable_security_tier && var.enable_systems_manager ? 1 : 0
  provider  = aws.primary
  name      = "/${local.common_name}/application/config"
  type      = "String"
  value = jsonencode({
    environment = var.common_tags.Environment
    region      = var.primary_region
    debug_mode  = var.development_mode
  })
  overwrite = true

  tags = {
    Name        = "${local.common_name}-app-config"
    Type        = "configuration-parameter"
    Environment = var.common_tags.Environment
  }
}

# ================================================================
# ROUTE 53 AND CERTIFICATE MANAGER
# ================================================================

# Route 53 hosted zone (optional)
resource "aws_route53_zone" "main" {
  count   = var.enable_security_tier && var.enable_certificate_manager && var.create_route53_zone ? 1 : 0
  provider = aws.primary
  name     = var.domain_name

  tags = {
    Name        = "${local.common_name}-hosted-zone"
    Type        = "dns-zone"
    Environment = var.common_tags.Environment
  }
}

# ACM certificate for domain
resource "aws_acm_certificate" "main" {
  count             = var.enable_security_tier && var.enable_certificate_manager ? 1 : 0
  provider          = aws.primary
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${local.common_name}-certificate"
    Type        = "ssl-certificate"
    Environment = var.common_tags.Environment
  }
}

# Certificate validation (only if Route 53 zone exists)
resource "aws_acm_certificate_validation" "main" {
  count           = var.enable_security_tier && var.enable_certificate_manager && var.create_route53_zone ? 1 : 0
  provider        = aws.primary
  certificate_arn = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Route 53 records for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_security_tier && var.enable_certificate_manager && var.create_route53_zone ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  provider = aws.primary
  zone_id  = aws_route53_zone.main[0].zone_id
  name     = each.value.name
  type     = each.value.type
  records  = [each.value.record]
  ttl      = 60

  allow_overwrite = true
}

# ================================================================
# AWS CLOUDTRAIL (ADVANCED)
# ================================================================

# CloudTrail S3 bucket
resource "aws_s3_bucket" "cloudtrail" {
  count    = var.enable_security_tier && var.enable_cloudtrail_advanced ? 1 : 0
  provider = aws.primary
  bucket   = "${local.common_name}-cloudtrail-${random_string.bucket_suffix[0].result}"

  tags = {
    Name        = "${local.common_name}-cloudtrail-bucket"
    Type        = "audit-logs"
    Environment = var.common_tags.Environment
  }
}

# Random string for bucket uniqueness
resource "random_string" "bucket_suffix" {
  count   = var.enable_security_tier && var.enable_cloudtrail_advanced ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# CloudTrail S3 bucket versioning
resource "aws_s3_bucket_versioning" "cloudtrail" {
  count    = var.enable_security_tier && var.enable_cloudtrail_advanced ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.cloudtrail[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# CloudTrail S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count    = var.enable_security_tier && var.enable_cloudtrail_advanced ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.security[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# CloudTrail S3 bucket policy
resource "aws_s3_bucket_policy" "cloudtrail" {
  count    = var.enable_security_tier && var.enable_cloudtrail_advanced ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  count          = var.enable_security_tier && var.enable_cloudtrail_advanced ? 1 : 0
  provider       = aws.primary
  name           = "${local.common_name}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail[0].bucket
  
  # Advanced settings
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  
  # Data events
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.cloudtrail[0].arn}/*"]
    }
  }

  # KMS encryption
  kms_key_id = aws_kms_key.security[0].arn

  tags = {
    Name        = "${local.common_name}-cloudtrail"
    Type        = "audit-trail"
    Environment = var.common_tags.Environment
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ================================================================
# AWS CONFIG
# ================================================================

# Config configuration recorder
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_security_tier && var.enable_aws_config ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Config delivery channel
resource "aws_config_delivery_channel" "main" {
  count          = var.enable_security_tier && var.enable_aws_config ? 1 : 0
  provider       = aws.primary
  name           = "${local.common_name}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].bucket
}

# Config S3 bucket
resource "aws_s3_bucket" "config" {
  count    = var.enable_security_tier && var.enable_aws_config ? 1 : 0
  provider = aws.primary
  bucket   = "${local.common_name}-config-${random_string.config_suffix[0].result}"

  tags = {
    Name        = "${local.common_name}-config-bucket"
    Type        = "compliance-logs"
    Environment = var.common_tags.Environment
  }
}

resource "random_string" "config_suffix" {
  count   = var.enable_security_tier && var.enable_aws_config ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# Config IAM role
resource "aws_iam_role" "config" {
  count    = var.enable_security_tier && var.enable_aws_config ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.common_name}-config-role"
  }
}

# Attach AWS managed policy to Config role
resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_security_tier && var.enable_aws_config ? 1 : 0
  provider   = aws.primary
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# ================================================================
# AMAZON GUARDDUTY
# ================================================================

# GuardDuty detector
resource "aws_guardduty_detector" "main" {
  count    = var.enable_security_tier && var.enable_guardduty ? 1 : 0
  provider = aws.primary
  enable   = true
  
  finding_publishing_frequency = var.guardduty_finding_format

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false  # No EKS in this lab
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.development_mode ? false : true  # Expensive feature
        }
      }
    }
  }

  tags = {
    Name        = "${local.common_name}-guardduty"
    Type        = "threat-detection"
    Environment = var.common_tags.Environment
  }
}

# ================================================================
# AWS SECURITY HUB
# ================================================================

# Security Hub
resource "aws_securityhub_account" "main" {
  count                    = var.enable_security_tier && var.enable_security_hub ? 1 : 0
  provider                 = aws.primary
  enable_default_standards = true

  control_finding_generator = "SECURITY_CONTROL"
}

# Enable AWS Config integration with Security Hub
resource "aws_securityhub_standards_subscription" "aws_config" {
  count         = var.enable_security_tier && var.enable_security_hub && var.enable_aws_config ? 1 : 0
  provider      = aws.primary
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard"
  depends_on    = [aws_securityhub_account.main]
}

# ================================================================
# SECURITY LOG GROUPS
# ================================================================

# Security events log group
resource "aws_cloudwatch_log_group" "security_events" {
  count             = var.enable_security_tier && var.enable_access_logging ? 1 : 0
  provider          = aws.primary
  name              = "/aws/security/${local.common_name}"
  retention_in_days = var.security_log_retention_days
  kms_key_id        = aws_kms_key.security[0].arn

  tags = {
    Name        = "${local.common_name}-security-events"
    Type        = "security-logs"
    Environment = var.common_tags.Environment
  }
}
