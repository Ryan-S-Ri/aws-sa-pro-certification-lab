#!/bin/bash
# implement-security-module.sh - Security & Identity module with validation framework

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}[SETUP]${NC} $1"; }

echo "🔐 AWS Certification Lab - Security & Identity Module Implementation"
echo "==================================================================="
echo ""

# Check prerequisites and run validation
print_status "Checking prerequisites and running validation..."
if [[ ! -f "main.tf" || ! -f "variables.tf" ]]; then
    print_error "Please run this script from your Terraform project root directory"
    exit 1
fi

# Run pre-existing validation if available
if [[ -f "scripts/validation/pre-deploy.sh" ]]; then
    print_status "Running existing validation framework..."
    if ! ./scripts/validation/pre-deploy.sh; then
        print_warning "Some validations failed, but continuing with security module setup..."
    fi
fi

print_success "✅ Prerequisites met"
echo ""

# Step 1: Add security variables to variables.tf
print_header "Adding Security & Identity variables to variables.tf..."
cat >> variables.tf << 'EOF'

# ================================================================
# SECURITY & IDENTITY VARIABLES
# ================================================================

# Core security toggles
variable "enable_security_tier" {
  description = "Enable security and identity tier"
  type        = bool
  default     = false
}

variable "enable_advanced_iam" {
  description = "Enable advanced IAM policies and roles"
  type        = bool
  default     = true
}

variable "enable_certificate_manager" {
  description = "Enable AWS Certificate Manager"
  type        = bool
  default     = true
}

variable "enable_systems_manager" {
  description = "Enable AWS Systems Manager"
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = "Enable AWS Config for compliance"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = false
}

variable "enable_cloudtrail_advanced" {
  description = "Enable advanced CloudTrail features"
  type        = bool
  default     = true
}

# Domain and certificate settings
variable "domain_name" {
  description = "Domain name for SSL certificate (use a domain you own or testing domain)"
  type        = string
  default     = "lab.example.com"
}

variable "create_route53_zone" {
  description = "Create Route 53 hosted zone for domain"
  type        = bool
  default     = false
}

# Security settings
variable "password_policy_enabled" {
  description = "Enable IAM account password policy"
  type        = bool
  default     = true
}

variable "mfa_required" {
  description = "Require MFA for sensitive operations"
  type        = bool
  default     = false  # Set to false for lab environment
}

variable "config_recorder_enabled" {
  description = "Enable AWS Config recorder"
  type        = bool
  default     = true
}

variable "guardduty_finding_format" {
  description = "GuardDuty finding publishing frequency"
  type        = string
  default     = "SIX_HOURS"
  
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_format)
    error_message = "GuardDuty finding format must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

# Cross-account access
variable "enable_cross_account_roles" {
  description = "Enable cross-account IAM roles"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs for cross-account access"
  type        = list(string)
  default     = []
}

# Compliance and auditing
variable "enable_access_logging" {
  description = "Enable access logging for security audit"
  type        = bool
  default     = true
}

variable "security_log_retention_days" {
  description = "Security log retention in days"
  type        = number
  default     = 90
  
  validation {
    condition     = var.security_log_retention_days >= 30 && var.security_log_retention_days <= 3653
    error_message = "Security log retention must be between 30 and 3653 days."
  }
}
EOF

print_success "✅ Security variables added to variables.tf"

# Step 2: Create security.tf file
print_header "Creating security.tf file..."
cat > security.tf << 'EOF'
# security.tf - Security & Identity Infrastructure for SA Pro
# Comprehensive security setup covering IAM, ACM, Config, GuardDuty, and compliance

# ================================================================
# DATA SOURCES
# ================================================================

# Current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Available AZs for multi-AZ resources
data "aws_availability_zones" "available" {
  state = "available"
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
      values = ["${aws_s3_bucket.lab_bucket.arn}/*"]
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

  tags = {
    Name        = "${local.common_name}-security-hub"
    Type        = "security-management"
    Environment = var.common_tags.Environment
  }
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
EOF

print_success "✅ security.tf created"

# Step 3: Add security outputs to outputs.tf
print_header "Adding security outputs to outputs.tf..."
cat >> outputs.tf << 'EOF'

# ================================================================
# SECURITY & IDENTITY OUTPUTS
# ================================================================

output "security_kms_key" {
  description = "KMS key for security services"
  value       = var.enable_security_tier ? aws_kms_key.security[0].arn : "Not deployed"
}

output "acm_certificate" {
  description = "ACM certificate details"
  value = var.enable_security_tier && var.enable_certificate_manager ? {
    arn         = aws_acm_certificate.main[0].arn
    domain_name = aws_acm_certificate.main[0].domain_name
    status      = aws_acm_certificate.main[0].status
  } : {}
}

output "route53_zone" {
  description = "Route 53 hosted zone details"
  value = var.enable_security_tier && var.enable_certificate_manager && var.create_route53_zone ? {
    zone_id     = aws_route53_zone.main[0].zone_id
    name_servers = aws_route53_zone.main[0].name_servers
  } : {}
}

output "systems_manager_parameters" {
  description = "Systems Manager parameter names"
  value = var.enable_security_tier && var.enable_systems_manager ? {
    db_password = aws_ssm_parameter.db_password[0].name
    redis_token = aws_ssm_parameter.redis_token[0].name
    app_config  = aws_ssm_parameter.app_config[0].name
  } : {}
  sensitive = true
}

output "cloudtrail_details" {
  description = "CloudTrail configuration"
  value = var.enable_security_tier && var.enable_cloudtrail_advanced ? {
    trail_arn    = aws_cloudtrail.main[0].arn
    s3_bucket    = aws_s3_bucket.cloudtrail[0].bucket
    kms_key_id   = aws_cloudtrail.main[0].kms_key_id
  } : {}
}

output "guardduty_detector" {
  description = "GuardDuty detector details"
  value = var.enable_security_tier && var.enable_guardduty ? {
    detector_id = aws_guardduty_detector.main[0].id
    status      = aws_guardduty_detector.main[0].enable
  } : {}
}

output "config_recorder" {
  description = "AWS Config recorder details"
  value = var.enable_security_tier && var.enable_aws_config ? {
    recorder_name = aws_config_configuration_recorder.main[0].name
    role_arn      = aws_config_configuration_recorder.main[0].role_arn
  } : {}
}

output "security_iam_roles" {
  description = "Security IAM role ARNs"
  value = var.enable_security_tier ? {
    security_auditor = var.enable_advanced_iam ? aws_iam_role.security_auditor[0].arn : "Not enabled"
    cross_account    = var.enable_cross_account_roles ? aws_iam_role.cross_account_access[0].arn : "Not enabled"
    config_role      = var.enable_aws_config ? aws_iam_role.config[0].arn : "Not enabled"
  } : {}
}
EOF

print_success "✅ Security outputs added to outputs.tf"

# Step 4: Update domain configurations
print_header "Updating domain configurations with security settings..."

# Update Domain 1: Security (where security is first introduced)
cat >> study-configs/domain1-security.tfvars << 'EOF'

# Security configuration for Domain 1
# Core security and identity settings

# Enable security tier
enable_security_tier = true

# Security feature toggles
enable_advanced_iam = true
enable_certificate_manager = false  # Skip SSL for cost
enable_systems_manager = true
enable_aws_config = true
enable_guardduty = true
enable_security_hub = false  # Expensive, keep disabled
enable_cloudtrail_advanced = true

# Domain and certificate settings (use example domain)
domain_name = "lab.example.com"
create_route53_zone = false  # Don't create actual DNS zone

# Security policies
password_policy_enabled = true
mfa_required = false  # Lab environment
config_recorder_enabled = true
guardduty_finding_format = "SIX_HOURS"

# Cross-account access (disabled for single account lab)
enable_cross_account_roles = false
trusted_account_ids = []

# Logging and compliance
enable_access_logging = true
security_log_retention_days = 30  # Cost optimized
EOF

# Update Domain 2: Resilient (inherits security + adds resilience)
cat >> study-configs/domain2-resilient.tfvars << 'EOF'

# Security configuration for Domain 2 (inherited from Domain 1)
enable_security_tier = true
enable_advanced_iam = true
enable_certificate_manager = false
enable_systems_manager = true
enable_aws_config = true
enable_guardduty = true
enable_security_hub = false
enable_cloudtrail_advanced = true

# Domain settings
domain_name = "lab.example.com"
create_route53_zone = false
password_policy_enabled = true
mfa_required = false
config_recorder_enabled = true
guardduty_finding_format = "SIX_HOURS"
enable_cross_account_roles = false
trusted_account_ids = []
enable_access_logging = true
security_log_retention_days = 30
EOF

# Update Domain 3: Performance (inherits security + adds performance)
cat >> study-configs/domain3-performance.tfvars << 'EOF'

# Security configuration for Domain 3 (inherited from previous domains)
enable_security_tier = true
enable_advanced_iam = true
enable_certificate_manager = true  # NOW enable SSL for ALB
enable_systems_manager = true
enable_aws_config = true
enable_guardduty = true
enable_security_hub = false
enable_cloudtrail_advanced = true

# Domain settings
domain_name = "lab.example.com"
create_route53_zone = false  # Still use example domain
password_policy_enabled = true
mfa_required = false
config_recorder_enabled = true
guardduty_finding_format = "SIX_HOURS"
enable_cross_account_roles = false
trusted_account_ids = []
enable_access_logging = true
security_log_retention_days = 30
EOF

# Update Domain 4: Cost Optimized (inherits all + adds cost features)
cat >> study-configs/domain4-cost-optimized.tfvars << 'EOF'

# Security configuration for Domain 4 (inherited + cost optimized)
enable_security_tier = true
enable_advanced_iam = true
enable_certificate_manager = true
enable_systems_manager = true
enable_aws_config = true
enable_guardduty = true
enable_security_hub = false  # Still expensive
enable_cloudtrail_advanced = true

# Domain settings
domain_name = "lab.example.com"
create_route53_zone = false
password_policy_enabled = true
mfa_required = false
config_recorder_enabled = true
guardduty_finding_format = "SIX_HOURS"  # Cost optimized frequency
enable_cross_account_roles = false
trusted_account_ids = []
enable_access_logging = true
security_log_retention_days = 30  # Cost optimized retention
EOF

# Update Full Lab (all security features enabled)
cat >> study-configs/full-lab.tfvars << 'EOF'

# Security configuration for Full Lab (all features)
enable_security_tier = true
enable_advanced_iam = true
enable_certificate_manager = true
enable_systems_manager = true
enable_aws_config = true
enable_guardduty = true
enable_security_hub = true  # NOW enable for full lab
enable_cloudtrail_advanced = true

# Domain settings (could use real domain if you have one)
domain_name = "lab.example.com"
create_route53_zone = false  # Set to true if you own the domain
password_policy_enabled = true
mfa_required = false  # Keep false for lab
config_recorder_enabled = true
guardduty_finding_format = "FIFTEEN_MINUTES"  # More frequent for full lab
enable_cross_account_roles = true  # Enable for advanced scenarios
trusted_account_ids = []  # Add actual account IDs if needed
enable_access_logging = true
security_log_retention_days = 90  # Longer retention for full lab
EOF

print_success "✅ Domain configurations updated"

# Step 5: Create security-only testing configuration
print_header "Creating security-only testing configuration..."
cat > study-configs/security-only.tfvars << 'EOF'
# Security-only configuration for focused security study
# Use this to test just the security components

# Disable other tiers to focus on security
enable_compute_tier = false
enable_database_tier = false
enable_monitoring_tier = false
enable_advanced_networking = false
enable_disaster_recovery = false

# Enable security tier
enable_security_tier = true

# Security feature toggles (core features for learning)
enable_advanced_iam = true
enable_certificate_manager = false  # Skip to reduce cost
enable_systems_manager = true
enable_aws_config = true
enable_guardduty = true
enable_security_hub = false  # Expensive
enable_cloudtrail_advanced = true

# Domain and certificate settings
domain_name = "lab.example.com"
create_route53_zone = false

# Security policies
password_policy_enabled = true
mfa_required = false
config_recorder_enabled = true
guardduty_finding_format = "SIX_HOURS"

# Cross-account access (disabled for simple lab)
enable_cross_account_roles = false
trusted_account_ids = []

# Cost-optimized settings for focused study
development_mode = true
log_retention_days = 3
security_log_retention_days = 30

# Basic settings
enable_security_features = true
enable_kms_advanced = true
enable_vpc_flow_logs = false  # Reduce noise for security focus

# Required variables for security features
mysql_master_password = "LabPassword123!"
redis_auth_token = "LabRedisAuth123456789!"

# Email for notifications
notification_email = "RRCloudDev@gmail.com"
EOF

print_success "✅ Security-only configuration created"

# Step 6: Create security helper scripts
print_header "Creating security helper scripts..."

# Security status script
cat > scripts/security-status.sh << 'EOF'
#!/bin/bash
# security-status.sh - Check security service status and configurations

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_security_overview() {
    print_status "Getting security infrastructure overview..."
    
    echo ""
    print_success "Security Services Status:"
    terraform output -json security_kms_key 2>/dev/null | jq -r 'if . == "Not deployed" then "❌ KMS Key: Not deployed" else "✅ KMS Key: \(.)" end' || echo "❌ KMS Key: Check deployment"
    
    terraform output -json guardduty_detector 2>/dev/null | jq -r 'if . == {} then "❌ GuardDuty: Not deployed" else "✅ GuardDuty: Enabled" end' || echo "❌ GuardDuty: Check deployment"
    
    terraform output -json config_recorder 2>/dev/null | jq -r 'if . == {} then "❌ AWS Config: Not deployed" else "✅ AWS Config: \(.recorder_name)" end' || echo "❌ AWS Config: Check deployment"
    
    terraform output -json cloudtrail_details 2>/dev/null | jq -r 'if . == {} then "❌ CloudTrail: Not deployed" else "✅ CloudTrail: Enabled" end' || echo "❌ CloudTrail: Check deployment"
}

show_certificate_status() {
    print_status "Checking SSL/TLS certificate status..."
    
    echo ""
    print_success "Certificate Information:"
    terraform output -json acm_certificate 2>/dev/null | jq -r 'if . == {} then "❌ ACM Certificate: Not deployed" else "✅ Certificate: \(.domain_name) (\(.status))" end' || echo "❌ Certificate: Check deployment"
    
    terraform output -json route53_zone 2>/dev/null | jq -r 'if . == {} then "❌ Route 53 Zone: Not created" else "✅ DNS Zone: \(.zone_id)" end' || echo "❌ Route 53: Not deployed"
}

show_iam_status() {
    print_status "Checking IAM configuration..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "IAM Account Settings:"
        
        # Check password policy
        if aws iam get-account-password-policy &>/dev/null; then
            echo "✅ Password Policy: Configured"
        else
            echo "❌ Password Policy: Not configured"
        fi
        
        # List custom roles
        echo ""
        print_success "Custom IAM Roles:"
        aws iam list-roles --query 'Roles[?contains(RoleName, `aws-cert-lab`)].RoleName' --output table 2>/dev/null || echo "No custom roles found"
    else
        echo "AWS CLI not available for IAM checks"
    fi
}

show_systems_manager() {
    print_status "Checking Systems Manager parameters..."
    
    echo ""
    print_success "SSM Parameters:"
    terraform output -json systems_manager_parameters 2>/dev/null | jq -r 'if . == {} then "❌ SSM Parameters: Not deployed" else "✅ Parameters: \(keys | join(", "))" end' || echo "❌ SSM: Check deployment"
    
    if command -v aws &> /dev/null; then
        echo ""
        print_warning "Parameter Details:"
        aws ssm describe-parameters --parameter-filters "Key=Name,Option=BeginsWith,Values=/aws-cert-lab" --query 'Parameters[].{Name:Name,Type:Type,LastModified:LastModifiedDate}' --output table 2>/dev/null || echo "No parameters found"
    fi
}

show_guardduty_findings() {
    print_status "Checking GuardDuty findings..."
    
    if command -v aws &> /dev/null; then
        local detector_id=$(terraform output -json guardduty_detector 2>/dev/null | jq -r '.detector_id // empty')
        
        if [[ -n "$detector_id" ]]; then
            echo ""
            print_success "GuardDuty Findings (Last 7 days):"
            aws guardduty list-findings --detector-id "$detector_id" --finding-criteria '{"updatedAt":{"gte":'"$(($(date +%s) - 604800))"'000}}' --query 'FindingIds' --output table 2>/dev/null || echo "No recent findings or insufficient permissions"
        else
            echo "❌ GuardDuty detector not found"
        fi
    else
        echo "AWS CLI not available for GuardDuty checks"
    fi
}

check_compliance() {
    print_status "Running basic compliance checks..."
    
    echo ""
    print_success "Compliance Status:"
    
    # Check encryption
    if terraform output -json security_kms_key 2>/dev/null | grep -q "arn:aws:kms"; then
        echo "✅ Encryption: KMS keys configured"
    else
        echo "❌ Encryption: No KMS keys found"
    fi
    
    # Check logging
    if terraform output -json cloudtrail_details 2>/dev/null | jq -e '. != {}' >/dev/null; then
        echo "✅ Audit Logging: CloudTrail enabled"
    else
        echo "❌ Audit Logging: CloudTrail not configured"
    fi
    
    # Check monitoring
    if terraform output -json guardduty_detector 2>/dev/null | jq -e '. != {}' >/dev/null; then
        echo "✅ Threat Detection: GuardDuty enabled"
    else
        echo "❌ Threat Detection: GuardDuty not configured"
    fi
}

case ${1:-""} in
    "overview"|"status"|"")
        show_security_overview
        ;;
    "certificates"|"cert"|"ssl")
        show_certificate_status
        ;;
    "iam"|"roles")
        show_iam_status
        ;;
    "ssm"|"parameters")
        show_systems_manager
        ;;
    "guardduty"|"threats")
        show_guardduty_findings
        ;;
    "compliance"|"audit")
        check_compliance
        ;;
    "all")
        show_security_overview
        echo ""
        show_certificate_status
        echo ""
        show_iam_status
        echo ""
        show_systems_manager
        echo ""
        check_compliance
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/security-status.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  overview, status  Show security services overview"
        echo "  certificates, ssl Show SSL certificate status"
        echo "  iam, roles        Show IAM configuration"
        echo "  ssm, parameters   Show Systems Manager parameters"
        echo "  guardduty, threats Show GuardDuty findings"
        echo "  compliance, audit Basic compliance check"
        echo "  all               Show all security information"
        echo "  help              Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/security-status.sh help' for usage"
        exit 1
        ;;
esac
EOF

chmod +x scripts/security-status.sh

# Security audit script
cat > scripts/security-audit.sh << 'EOF'
#!/bin/bash
# security-audit.sh - Perform security audit and recommendations

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "🔍 Security Audit Report"
echo "======================="
echo ""

audit_score=0
total_checks=0

check_item() {
    local name="$1"
    local command="$2"
    local success_msg="$3"
    local fail_msg="$4"
    
    ((total_checks++))
    print_status "Checking: $name..."
    
    if eval "$command" &>/dev/null; then
        print_success "$success_msg"
        ((audit_score++))
    else
        print_error "$fail_msg"
    fi
}

# Security service checks
print_status "=== SECURITY SERVICES ==="
check_item "KMS Encryption" \
    'terraform output -json security_kms_key | grep -q "arn:aws:kms"' \
    "KMS encryption keys are configured" \
    "KMS encryption keys are missing"

check_item "GuardDuty Detection" \
    'terraform output -json guardduty_detector | jq -e ".detector_id" >/dev/null' \
    "GuardDuty threat detection is enabled" \
    "GuardDuty is not configured"

check_item "CloudTrail Logging" \
    'terraform output -json cloudtrail_details | jq -e ".trail_arn" >/dev/null' \
    "CloudTrail audit logging is enabled" \
    "CloudTrail is not configured"

check_item "AWS Config Compliance" \
    'terraform output -json config_recorder | jq -e ".recorder_name" >/dev/null' \
    "AWS Config compliance monitoring is enabled" \
    "AWS Config is not configured"

echo ""
print_status "=== IAM SECURITY ==="
check_item "Password Policy" \
    'aws iam get-account-password-policy' \
    "IAM password policy is configured" \
    "IAM password policy is missing"

check_item "Custom Security Roles" \
    'terraform output -json security_iam_roles | jq -e ".security_auditor" >/dev/null' \
    "Custom security roles are configured" \
    "Custom security roles are missing"

echo ""
print_status "=== DATA PROTECTION ==="
check_item "Systems Manager Parameters" \
    'terraform output -json systems_manager_parameters | jq -e ".db_password" >/dev/null' \
    "Secrets are stored in Systems Manager" \
    "Systems Manager parameters are missing"

check_item "S3 Bucket Encryption" \
    'aws s3api get-bucket-encryption --bucket $(terraform output -raw lab_bucket_name) 2>/dev/null' \
    "S3 buckets have encryption enabled" \
    "S3 bucket encryption may be missing"

echo ""
print_status "=== NETWORK SECURITY ==="
check_item "VPC Flow Logs" \
    'terraform output -json monitoring_log_groups | jq -e ".vpc_flow_logs" >/dev/null' \
    "VPC Flow Logs are enabled for network monitoring" \
    "VPC Flow Logs are not configured"

# Calculate security score
echo ""
print_status "=== SECURITY SCORE ==="
percentage=$((audit_score * 100 / total_checks))

if [[ $percentage -ge 90 ]]; then
    print_success "Security Score: $audit_score/$total_checks ($percentage%) - EXCELLENT"
elif [[ $percentage -ge 75 ]]; then
    print_success "Security Score: $audit_score/$total_checks ($percentage%) - GOOD"
elif [[ $percentage -ge 60 ]]; then
    print_warning "Security Score: $audit_score/$total_checks ($percentage%) - NEEDS IMPROVEMENT"
else
    print_error "Security Score: $audit_score/$total_checks ($percentage%) - CRITICAL ISSUES"
fi

echo ""
print_status "=== RECOMMENDATIONS ==="
if [[ $audit_score -lt $total_checks ]]; then
    echo "🔧 To improve your security posture:"
    echo "   1. Deploy missing security services"
    echo "   2. Enable all monitoring and logging"
    echo "   3. Review IAM policies and roles"
    echo "   4. Ensure all data is encrypted"
    echo "   5. Run: ./study-deploy.sh domain1 (for security focus)"
fi

echo ""
print_status "=== COST ESTIMATE ==="
print_warning "Security services estimated cost:"
echo "   • GuardDuty: ~$3-5/month"
echo "   • AWS Config: ~$2-4/month"
echo "   • CloudTrail: ~$1-3/month"
echo "   • KMS: ~$1/month"
echo "   • Systems Manager: Free tier"
echo "   • Total: ~$7-13/month"
EOF

chmod +x scripts/security-audit.sh

print_success "✅ Security helper scripts created"

# Step 7: Update study-deploy.sh
print_header "Updating study-deploy.sh with security commands..."

# Add security command to the help section
if ! grep -q "security" study-deploy.sh; then
    sed -i '/  monitoring      Deploy monitoring-only configuration/a\
  security        Deploy security-only configuration (focused study)' study-deploy.sh

    # Add security case to the main function
    sed -i '/        "monitoring"|"mon") deploy_domain "monitoring-only" ;;/a\
        "security"|"sec") deploy_domain "security-only" ;;' study-deploy.sh
fi

print_success "✅ study-deploy.sh updated with security commands"

# Step 8: Run validation
print_header "Running validation checks..."

# Check if validation framework exists and run it
if [[ -f "scripts/validation/pre-deploy.sh" ]]; then
    print_status "Running pre-deployment validation..."
    if ./scripts/validation/pre-deploy.sh; then
        print_success "✅ All validations passed!"
    else
        print_warning "⚠️  Some validation issues found, but security module setup complete"
    fi
else
    # Run basic terraform validation
    print_status "Running basic Terraform validation..."
    if terraform validate; then
        print_success "✅ Terraform configuration is valid"
    else
        print_warning "⚠️  Terraform validation failed - please check configuration"
    fi
fi

echo ""
print_success "🎉 Security & Identity Module Implementation Complete!"
echo ""
print_status "Files created/modified:"
echo "  ✅ security.tf - Complete security infrastructure"
echo "  ✅ variables.tf - Security variables added"
echo "  ✅ outputs.tf - Security outputs added"
echo "  ✅ study-configs/domain1-security.tfvars - Updated with security settings"
echo "  ✅ study-configs/domain2-resilient.tfvars - Inherited security settings"
echo "  ✅ study-configs/domain3-performance.tfvars - Security + SSL certificates"
echo "  ✅ study-configs/domain4-cost-optimized.tfvars - Security + cost optimization"
echo "  ✅ study-configs/full-lab.tfvars - All security features"
echo "  ✅ study-configs/security-only.tfvars - Security-focused configuration"
echo "  ✅ scripts/security-status.sh - Security service status checker"
echo "  ✅ scripts/security-audit.sh - Comprehensive security audit"
echo "  ✅ study-deploy.sh - Updated with security commands"
echo ""
print_warning "💰 Security Cost Estimates:"
echo "  Security-only: ~$7-13/day (GuardDuty, Config, CloudTrail, KMS)"
echo "  Domain 1: ~$10-15/day (Security + basic networking)"
echo "  Domain 3: ~$15-25/day (Security + compute + database)"
echo "  Full Lab: ~$30-45/day (All features + Security Hub)"
echo ""
print_status "Next steps:"
echo "  1. Test security-only: ./study-deploy.sh security"
echo "  2. Or progress from Domain 1: ./study-deploy.sh domain1"
echo "  3. Check security status: ./scripts/security-status.sh overview"
echo "  4. Run security audit: ./scripts/security-audit.sh"
echo "  5. Always destroy after study: ./study-deploy.sh destroy"
echo ""
print_success "🔐 Ready to deploy your security infrastructure!"
echo ""
print_warning "📋 What you get with the security tier:"
echo "  🔹 Advanced IAM roles and policies"
echo "  🔹 AWS Certificate Manager for SSL/TLS"
echo "  🔹 Systems Manager Parameter Store for secrets"
echo "  🔹 AWS Config for compliance monitoring"
echo "  🔹 Amazon GuardDuty for threat detection"
echo "  🔹 CloudTrail for comprehensive audit logging"
echo "  🔹 KMS encryption for all security services"
echo "  🔹 Security Hub for centralized security (full lab)"
echo "  🔹 IAM password policy enforcement"
echo "  🔹 Cross-account role capabilities"
echo ""
print_success "Secure your cloud with confidence! 🛡️"
