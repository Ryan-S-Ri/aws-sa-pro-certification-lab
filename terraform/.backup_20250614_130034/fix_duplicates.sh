#!/bin/bash
# fix-duplicates.sh - Clean up duplicate variables and outputs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🧹 Fixing Duplicate Variables and Outputs"
echo "========================================="

# Backup original files
print_status "Creating backups..."
cp variables.tf variables.tf.backup-$(date +%Y%m%d-%H%M%S)
cp outputs.tf outputs.tf.backup-$(date +%Y%m%d-%H%M%S)
cp security.tf security.tf.backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true

print_success "✅ Backups created"

# Fix variables.tf - remove duplicates
print_status "Fixing variables.tf duplicates..."

# Find where duplicates start and remove everything after the first occurrence
# Keep only unique variables

# Create a clean variables file
cat > variables.tf.clean << 'EOF'
# Variables for AWS Certification Lab - Complete Version

variable "primary_region" {
  description = "Primary AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "testbed_region" {
  description = "Testbed region for DR and testing"
  type        = string
  default     = "us-east-2"
}

variable "networking_region" {
  description = "Region for advanced networking scenarios"
  type        = string
  default     = "us-west-1"
}

variable "notification_email" {
  description = "Email address for notifications and alerts"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Please provide a valid email address."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "certification-lab"
    Project     = "aws-cert-prep"
    ManagedBy   = "terraform"
    Platform    = "raspberry-pi"
  }
}

variable "development_mode" {
  description = "Enable development mode for cost optimization"
  type        = bool
  default     = true
}

# Networking variables
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (cost consideration)"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway for hybrid connectivity testing"
  type        = bool
  default     = false
}

# Compute variables
variable "instance_types" {
  description = "Instance types for different tiers"
  type        = map(string)
  default = {
    web_tier = "t3.micro"
    app_tier = "t3.micro"
    bastion  = "t3.nano"
  }
}

variable "key_pair_name" {
  description = "Name of the SSH key pair for EC2 instances"
  type        = string
  default     = "aws-cert-lab-key"
}

# Database variables
variable "database_instance_class" {
  description = "RDS instance class for Aurora cluster"
  type        = string
  default     = "db.t3.micro"
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ deployment for databases"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 1
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

# Feature toggles
variable "enable_compute_tier" {
  description = "Enable EC2 compute infrastructure"
  type        = bool
  default     = false
}

variable "enable_database_tier" {
  description = "Enable database infrastructure"
  type        = bool
  default     = false
}

variable "enable_monitoring_tier" {
  description = "Enable monitoring and observability"
  type        = bool
  default     = false
}

variable "enable_sap_c02_features" {
  description = "Enable SAP-C02 specific features"
  type        = bool
  default     = false
}

# Security variables
variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Monitoring variables
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 3
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

# Database tier variables
variable "enable_postgresql" {
  description = "Enable PostgreSQL Aurora cluster in addition to MySQL"
  type        = bool
  default     = false
}

variable "enable_dynamodb" {
  description = "Enable DynamoDB tables"
  type        = bool
  default     = true
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager for database credentials"
  type        = bool
  default     = true
}

variable "mysql_database_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "labdb"
}

variable "mysql_master_username" {
  description = "Master username for MySQL database"
  type        = string
  default     = "admin"
}

variable "mysql_master_password" {
  description = "Master password for MySQL database"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "labpgdb"
}

variable "postgresql_master_username" {
  description = "Master username for PostgreSQL database"
  type        = string
  default     = "postgres"
}

variable "postgresql_master_password" {
  description = "Master password for PostgreSQL database"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Auth token for Redis cluster"
  type        = string
  default     = "MyRedisAuthToken123!"
  sensitive   = true
}

variable "enable_elasticache" {
  description = "Enable ElastiCache for caching"
  type        = bool
  default     = true
}

variable "enable_database_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = false
}

variable "enable_kms_advanced" {
  description = "Enable advanced KMS features"
  type        = bool
  default     = false
}

# Monitoring tier variables  
variable "enable_cost_monitoring" {
  description = "Enable cost monitoring and budgets"
  type        = bool
  default     = true
}

variable "enable_security_monitoring" {
  description = "Enable security-focused monitoring"
  type        = bool
  default     = true
}

variable "enable_eventbridge" {
  description = "Enable EventBridge rules and targets"
  type        = bool
  default     = true
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_lambda_monitoring" {
  description = "Enable Lambda function monitoring"
  type        = bool
  default     = false
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "50"
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "rds_connection_threshold" {
  description = "RDS connection count threshold for alarms"
  type        = number
  default     = 80
}

# Security & Identity tier variables
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

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "lab.example.com"
}

variable "create_route53_zone" {
  description = "Create Route 53 hosted zone for domain"
  type        = bool
  default     = false
}

variable "password_policy_enabled" {
  description = "Enable IAM account password policy"
  type        = bool
  default     = true
}

variable "mfa_required" {
  description = "Require MFA for sensitive operations"
  type        = bool
  default     = false
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

variable "enable_security_features" {
  description = "Enable comprehensive security features"
  type        = bool
  default     = false
}
EOF

# Replace with clean version
mv variables.tf.clean variables.tf
print_success "✅ variables.tf cleaned"

# Fix outputs.tf - remove duplicate outputs
print_status "Fixing outputs.tf duplicates..."

# Get the line number where security outputs start to appear
first_security_output=$(grep -n "security_kms_key" outputs.tf | head -1 | cut -d: -f1)

if [[ -n "$first_security_output" ]]; then
    # Keep everything before the first security output, then add clean security outputs
    head -n $((first_security_output - 1)) outputs.tf > outputs.tf.clean
    
    # Add clean security outputs
    cat >> outputs.tf.clean << 'EOF'

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

    mv outputs.tf.clean outputs.tf
    print_success "✅ outputs.tf cleaned"
else
    print_warning "No duplicate security outputs found to clean"
fi

# Fix security.tf - remove duplicate data sources
print_status "Fixing security.tf data source duplicates..."

if [[ -f "security.tf" ]]; then
    # Remove the duplicate data sources from security.tf
    sed -i '/^# Current AWS account and region$/,/^data "aws_availability_zones" "available"/c\
# Available AZs for multi-AZ resources\
data "aws_availability_zones" "available" {\
  state = "available"\
}' security.tf
    
    print_success "✅ security.tf data sources fixed"
fi

# Validation
print_status "Running validation..."
if terraform validate; then
    print_success "✅ Terraform configuration is now valid!"
else
    print_error "❌ Still have validation issues. Let me check..."
    terraform validate
fi

echo ""
print_success "🎉 Duplicate cleanup complete!"
echo ""
print_status "What was fixed:"
echo "  ✅ Removed duplicate variables from variables.tf"
echo "  ✅ Removed duplicate outputs from outputs.tf"
echo "  ✅ Fixed duplicate data sources in security.tf"
echo "  ✅ Created backups of original files"
echo ""
print_warning "If you still have issues, you can restore from backups:"
echo "  cp variables.tf.backup-* variables.tf"
echo "  cp outputs.tf.backup-* outputs.tf"
echo ""
print_success "Ready to deploy! Try: terraform validate"
