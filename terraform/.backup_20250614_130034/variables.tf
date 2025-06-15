variable "common_name" {
  description = "Common name prefix"
  type        = string
  default     = "sa-pro-lab"
}

variable "primary_region" {
  description = "Primary region"
  type        = string
  default     = "us-east-1"
}

variable "testbed_region" {
  description = "Secondary region"
  type        = string
  default     = "us-east-2"
}

variable "notification_email" {
  description = "Email for notifications"
  type        = string
  sensitive   = true
}

# All the enable flags (set to false by default)
variable "enable_compute_tier" { type = bool; default = false }
variable "enable_database_tier" { type = bool; default = false }
variable "enable_serverless_tier" { type = bool; default = false }
variable "enable_storage_tier" { type = bool; default = false }
variable "enable_monitoring_tier" { type = bool; default = false }
variable "enable_security_tier" { type = bool; default = false }
variable "enable_advanced_networking" { type = bool; default = false }
variable "enable_vpc_peering" { type = bool; default = false }
variable "enable_route53_advanced" { type = bool; default = false }
variable "enable_cloudfront" { type = bool; default = false }
variable "enable_network_firewall" { type = bool; default = false }
variable "enable_transit_gateway" { type = bool; default = false }
variable "enable_nat_gateway" { type = bool; default = false }
variable "enable_vpn_gateway" { type = bool; default = false }
variable "enable_vpc_flow_logs" { type = bool; default = false }
variable "enable_api_gateway" { type = bool; default = false }
variable "enable_http_api" { type = bool; default = false }
variable "enable_step_functions" { type = bool; default = false }
variable "enable_eventbridge" { type = bool; default = false }
variable "enable_eventbridge_advanced" { type = bool; default = false }
variable "enable_xray" { type = bool; default = false }
variable "enable_dynamodb" { type = bool; default = false }
variable "enable_dynamodb_streams" { type = bool; default = false }
variable "enable_elasticache" { type = bool; default = false }
variable "enable_postgresql" { type = bool; default = false }
variable "enable_secrets_manager" { type = bool; default = true }
variable "enable_kms_advanced" { type = bool; default = false }
variable "enable_cloudtrail_advanced" { type = bool; default = false }
variable "enable_aws_config" { type = bool; default = false }
variable "enable_sns_email" { type = bool; default = false }
variable "enable_cost_monitoring" { type = bool; default = false }

# Basic settings
variable "development_mode" { type = bool; default = true }
variable "enable_multi_az" { type = bool; default = false }
variable "backup_retention_days" { type = number; default = 1 }
variable "monthly_budget_limit" { type = number; default = 10 }
variable "log_retention_days" { type = number; default = 1 }

# Required variables (even if not used)
variable "mysql_master_password" { type = string; sensitive = true }
variable "mysql_master_username" { type = string; default = "admin" }
variable "mysql_database_name" { type = string; default = "tempdb" }
variable "redis_auth_token" { type = string; sensitive = true }
variable "ssh_allowed_cidrs" { type = list(string); default = [] }
variable "domain_name" { type = string; default = "temp.local" }

variable "common_tags" {
  type = map(string)
  default = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}
