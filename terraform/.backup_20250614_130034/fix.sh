# =================================================================
# ONE-SHOT COMPLETE FIX - NO MORE BACK AND FORTH!
# =================================================================

# This script will fix ALL issues at once by:
# 1. Creating a completely clean variables.tf with ALL needed variables
# 2. Updating terraform.tfvars with correct values
# 3. Disabling problematic features temporarily

echo "🔧 Starting complete Terraform fix..."

# =================================================================
# STEP 1: CREATE COMPLETE variables.tf (ALL VARIABLES INCLUDED)
# =================================================================

cat > variables.tf << 'EOF'
# Core infrastructure variables
variable "common_name" {
  description = "Common name prefix for all resources"
  type        = string
  default     = "sa-pro-lab"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.common_name))
    error_message = "Common name must contain only alphanumeric characters and hyphens."
  }
}

variable "primary_region" {
  description = "Primary AWS region for SA Pro exam"
  type        = string
  default     = "us-east-1"
}

variable "testbed_region" {
  description = "Secondary AWS region for multi-region scenarios"
  type        = string
  default     = "us-east-2"
}

variable "notification_email" {
  description = "Email address for notifications and alarms"
  type        = string
  sensitive   = true
}

# Environment and cost control
variable "development_mode" {
  description = "Enable development mode with cost optimizations"
  type        = bool
  default     = true
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ deployments (costs more)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 1
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 50
}

# Tier toggles - enable/disable entire tiers
variable "enable_compute_tier" {
  description = "Enable EC2 compute resources"
  type        = bool
  default     = false
}

variable "enable_database_tier" {
  description = "Enable RDS and database resources"
  type        = bool
  default     = false
}

variable "enable_serverless_tier" {
  description = "Enable Lambda and serverless resources"
  type        = bool
  default     = true
}

variable "enable_storage_tier" {
  description = "Enable S3 and storage resources"
  type        = bool
  default     = true
}

variable "enable_monitoring_tier" {
  description = "Enable CloudWatch and monitoring"
  type        = bool
  default     = false
}

variable "enable_security_tier" {
  description = "Enable security services (GuardDuty, etc.)"
  type        = bool
  default     = false
}

# Networking features
variable "enable_advanced_networking" {
  description = "Enable advanced networking features"
  type        = bool
  default     = false
}

variable "enable_vpc_peering" {
  description = "Enable VPC peering connections"
  type        = bool
  default     = false
}

variable "enable_route53_advanced" {
  description = "Enable advanced Route53 features"
  type        = bool
  default     = false
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution"
  type        = bool
  default     = false
}

variable "enable_network_firewall" {
  description = "Enable AWS Network Firewall"
  type        = bool
  default     = false
}

variable "enable_transit_gateway" {
  description = "Enable AWS Transit Gateway"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = false
}

# API and serverless features
variable "enable_api_gateway" {
  description = "Enable API Gateway REST API"
  type        = bool
  default     = true
}

variable "enable_http_api" {
  description = "Enable API Gateway HTTP API"
  type        = bool
  default     = false
}

variable "enable_step_functions" {
  description = "Enable AWS Step Functions"
  type        = bool
  default     = false
}

variable "enable_eventbridge" {
  description = "Enable EventBridge basic features"
  type        = bool
  default     = false
}

variable "enable_eventbridge_advanced" {
  description = "Enable advanced EventBridge features"
  type        = bool
  default     = false
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

# Database features
variable "enable_dynamodb" {
  description = "Enable DynamoDB tables"
  type        = bool
  default     = false
}

variable "enable_dynamodb_streams" {
  description = "Enable DynamoDB Streams"
  type        = bool
  default     = false
}

variable "enable_elasticache" {
  description = "Enable ElastiCache clusters"
  type        = bool
  default     = false
}

variable "enable_postgresql" {
  description = "Enable PostgreSQL RDS cluster"
  type        = bool
  default     = false
}

variable "enable_database_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for resources"
  type        = bool
  default     = false
}

# Security and compliance features
variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager"
  type        = bool
  default     = true
}

variable "enable_kms_advanced" {
  description = "Enable advanced KMS encryption"
  type        = bool
  default     = false
}

variable "enable_cloudtrail_advanced" {
  description = "Enable advanced CloudTrail features"
  type        = bool
  default     = false
}

variable "enable_aws_config" {
  description = "Enable AWS Config service"
  type        = bool
  default     = false
}

variable "enable_sns_email" {
  description = "Enable SNS email notifications"
  type        = bool
  default     = false
}

# Cost and monitoring
variable "enable_cost_monitoring" {
  description = "Enable cost monitoring and budgets"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 7
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms"
  type        = number
  default     = 80
}

# Instance and resource sizing
variable "instance_types" {
  description = "EC2 instance types for different tiers"
  type        = map(string)
  default = {
    web_tier = "t3.micro"
    app_tier = "t3.micro"
    bastion  = "t3.nano"
  }
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

# API throttling
variable "api_throttle_rate" {
  description = "API Gateway throttling rate limit"
  type        = number
  default     = 100
}

variable "api_throttle_burst" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 200
}

# Security settings
variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed SSH access"
  type        = list(string)
  default     = []
}

variable "key_pair_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "sa-pro-lab-key"
}

# Sensitive variables (passwords, tokens)
variable "mysql_master_password" {
  description = "MySQL master password"
  type        = string
  sensitive   = true
}

variable "mysql_master_username" {
  description = "MySQL master username"
  type        = string
  default     = "admin"
}

variable "mysql_database_name" {
  description = "MySQL database name"
  type        = string
  default     = "sapro_lab_db"
}

variable "redis_auth_token" {
  description = "Redis authentication token"
  type        = string
  sensitive   = true
}

# Domain and DNS
variable "domain_name" {
  description = "Domain name for DNS and certificates"
  type        = string
  default     = "sa-pro-lab.local"
}

# Advanced networking
variable "transit_gateway_asn" {
  description = "ASN for Transit Gateway"
  type        = number
  default     = 64512
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

# Additional toggles
variable "enable_sap_c02_features" {
  description = "Enable specific SAP-C02 exam features"
  type        = bool
  default     = false
}

# Common tags
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "sa-pro-lab"
    Project     = "aws-certification"
    ManagedBy   = "terraform"
    Owner       = "ryan"
    CostCenter  = "learning"
    ExamTrack   = "SAP-C02"
  }
}
EOF

# =================================================================
# STEP 2: CREATE CLEAN terraform.tfvars
# =================================================================

cat > terraform.tfvars << 'EOF'
# SA Pro Exam Lab Configuration
common_name = "sa-pro-lab"
primary_region = "us-east-1"
testbed_region = "us-east-2"
notification_email = "RRCloudDev@gmail.com"

# Cost optimization settings
development_mode = true
enable_multi_az = false
backup_retention_days = 1
monthly_budget_limit = 50
log_retention_days = 7

# Infrastructure tiers - start minimal
enable_compute_tier = false
enable_database_tier = false
enable_serverless_tier = true
enable_storage_tier = true
enable_monitoring_tier = false
enable_security_tier = false

# Networking - disabled for cost control
enable_advanced_networking = false
enable_vpc_peering = false
enable_route53_advanced = false
enable_cloudfront = false
enable_network_firewall = false
enable_transit_gateway = false
enable_nat_gateway = false
enable_vpn_gateway = false
enable_vpc_flow_logs = false

# API and serverless
enable_api_gateway = true
enable_http_api = false
enable_step_functions = false
enable_eventbridge = false
enable_eventbridge_advanced = false
enable_xray = false

# Database features - disabled initially
enable_dynamodb = false
enable_dynamodb_streams = false
enable_elasticache = false
enable_postgresql = false
enable_database_performance_insights = false
enable_detailed_monitoring = false

# Security features
enable_secrets_manager = true
enable_kms_advanced = false
enable_cloudtrail_advanced = false
enable_aws_config = false
enable_sns_email = false

# Cost monitoring
enable_cost_monitoring = true

# Resource sizing for cost optimization
instance_types = {
  web_tier = "t3.micro"
  app_tier = "t3.micro"
  bastion  = "t3.nano"
}

database_instance_class = "db.t3.micro"

# API throttling
api_throttle_rate = 100
api_throttle_burst = 200

# Security
ssh_allowed_cidrs = ["107.11.16.91/32"]
key_pair_name = "sa-pro-lab-key"

# Domain
domain_name = "sa-pro-lab.local"

# Sensitive variables - CHANGE THESE!
mysql_master_password = "ChangeMe123!@#"
mysql_master_username = "admin"
mysql_database_name = "sapro_lab_db"
redis_auth_token = "ChangeRedisToken456!@#"

# Advanced features
enable_sap_c02_features = false
EOF

# =================================================================
# STEP 3: VALIDATE AND TEST
# =================================================================

echo "✅ Created complete variables.tf with ALL needed variables"
echo "✅ Created clean terraform.tfvars with cost-optimized settings"
echo ""
echo "🔐 IMPORTANT: Update your passwords in terraform.tfvars before running terraform!"
echo ""
echo "Next steps:"
echo "1. Edit terraform.tfvars and change the passwords"
echo "2. Run: terraform validate"
echo "3. Run: terraform plan"
echo "4. Run: terraform destroy (if you want to clean up)"
echo ""
echo "The configuration is now set to:"
echo "- Use us-east-1 as primary region for SA Pro exam"
echo "- Start with minimal serverless features only"
echo "- Keep costs under $50/month"
echo "- Allow you to enable features incrementally"