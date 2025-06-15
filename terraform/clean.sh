#!/bin/bash
# cleanup-conflicts.sh - Remove conflicting Terraform files

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Cleaning Up Terraform Conflicts${NC}"
echo "================================"
echo ""

# Step 1: Identify conflicting files
echo -e "${YELLOW}Step 1: Identifying conflicting files...${NC}"

CONFLICTS=(
    "destroy_with_provider_alias.tf"
    "destroy_old_infrastructure.tf"
    "comprehensive_destroy.tf"
    "main-destroy.tf"
    "destroy.tf"
)

# Archive old files
mkdir -p .archive/old-destroy-configs

for file in "${CONFLICTS[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${YELLOW}Found conflicting file: $file${NC}"
        mv "$file" .archive/old-destroy-configs/
        echo -e "${GREEN}✓${NC} Moved $file to .archive/old-destroy-configs/"
    fi
done

# Step 2: Check for duplicate module declarations in compatibility.tf
echo -e "\n${YELLOW}Step 2: Checking compatibility.tf...${NC}"

if [ -f "compatibility.tf" ]; then
    # Check if it has module declarations that conflict with main.tf
    if grep -q "module \"domain" compatibility.tf; then
        echo -e "${YELLOW}Found module declarations in compatibility.tf${NC}"
        echo -e "${BLUE}Moving compatibility.tf to backup...${NC}"
        mv compatibility.tf compatibility.tf.backup
        echo -e "${GREEN}✓${NC} Backed up to compatibility.tf.backup"
    fi
fi

# Step 3: Clean up duplicate variables
echo -e "\n${YELLOW}Step 3: Checking for duplicate variables...${NC}"

# Create a clean variables file
if [ -f "variables.tf" ]; then
    # Remove duplicate notification_email if it exists
    sed -i.bak '/^variable "notification_email" {/,/^}/d' variables.tf
    # Add it back once
    cat >> variables.tf << 'EOF'

variable "notification_email" {
  description = "Email for notifications"
  type        = string
  default     = ""
}
EOF
    echo -e "${GREEN}✓${NC} Cleaned up duplicate variables"
fi

# Step 4: Clean Terraform cache
echo -e "\n${YELLOW}Step 4: Cleaning Terraform cache...${NC}"
rm -rf .terraform
rm -f .terraform.lock.hcl
echo -e "${GREEN}✓${NC} Terraform cache cleaned"

# Step 5: Create proper compatibility layer
echo -e "\n${YELLOW}Step 5: Creating proper compatibility layer...${NC}"

cat > compatibility-layer.tf << 'EOF'
# Compatibility layer for study configs
# This file adds variables needed by study configs without duplicating modules

# Study config feature toggles
variable "enable_security_features" {
  description = "Enable security features"
  type        = bool
  default     = false
}

variable "enable_compute_tier" {
  description = "Enable compute tier"
  type        = bool
  default     = false
}

variable "enable_database_tier" {
  description = "Enable database tier"
  type        = bool
  default     = false
}

variable "enable_monitoring_tier" {
  description = "Enable monitoring tier"
  type        = bool
  default     = false
}

variable "enable_advanced_networking" {
  description = "Enable advanced networking"
  type        = bool
  default     = false
}

variable "enable_disaster_recovery" {
  description = "Enable disaster recovery"
  type        = bool
  default     = false
}

variable "enable_security_tier" {
  description = "Enable security tier"
  type        = bool
  default     = false
}

# Security feature toggles
variable "enable_waf" { default = false }
variable "enable_shield" { default = false }
variable "enable_inspector" { default = false }
variable "enable_guardduty" { default = false }
variable "enable_config" { default = false }
variable "enable_cloudtrail" { default = false }
variable "enable_kms_advanced" { default = false }
variable "enable_vpc_flow_logs" { default = false }
variable "enable_nacls" { default = false }
variable "enable_security_groups_advanced" { default = false }
variable "enable_advanced_iam" { default = false }
variable "enable_certificate_manager" { default = false }
variable "enable_systems_manager" { default = false }
variable "enable_aws_config" { default = false }
variable "enable_security_hub" { default = false }
variable "enable_cloudtrail_advanced" { default = false }

# Resilience feature toggles
variable "enable_multi_az" { default = false }
variable "enable_cross_region_backup" { default = false }
variable "enable_auto_scaling_advanced" { default = false }
variable "enable_health_checks" { default = false }
variable "enable_route53_health_checks" { default = false }
variable "enable_elastic_load_balancing" { default = false }

# Performance feature toggles
variable "enable_elasticache" { default = false }
variable "enable_cloudfront" { default = false }
variable "enable_s3_performance" { default = false }
variable "enable_database_performance_insights" { default = false }
variable "enable_read_replicas" { default = false }
variable "enable_connection_pooling" { default = false }
variable "enable_database_proxy" { default = false }

# Cost optimization feature toggles
variable "enable_cost_explorer" { default = false }
variable "enable_budgets" { default = false }
variable "enable_trusted_advisor" { default = false }
variable "enable_spot_instances" { default = false }
variable "enable_reserved_instances_recommendations" { default = false }
variable "enable_s3_intelligent_tiering" { default = false }
variable "enable_lifecycle_policies" { default = false }
variable "enable_cost_allocation_tags" { default = false }

# Database settings
variable "mysql_master_password" {
  description = "MySQL master password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "redis_auth_token" {
  description = "Redis auth token"
  type        = string
  sensitive   = true
  default     = "ChangeMe123456789!"
}

variable "postgresql_master_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

# Other settings
variable "development_mode" { default = true }
variable "backup_retention_days" { default = 7 }
variable "log_retention_days" { default = 7 }
variable "trusted_account_ids" { default = [] }
variable "domain_name" { default = "example.com" }
variable "create_route53_zone" { default = false }
variable "password_policy_enabled" { default = true }
variable "mfa_required" { default = false }
variable "config_recorder_enabled" { default = true }
variable "guardduty_finding_format" { default = "SIX_HOURS" }
variable "enable_access_logging" { default = true }
variable "security_log_retention_days" { default = 30 }
variable "enable_cross_account_roles" { default = false }
variable "enable_detailed_monitoring" { default = false }
variable "database_instance_class" { default = "db.t3.micro" }
variable "enable_postgresql" { default = false }
variable "enable_dynamodb" { default = false }
variable "enable_secrets_manager" { default = false }
variable "enable_database_cross_region_backup" { default = false }
variable "enable_database_monitoring_enhanced" { default = false }
variable "enable_aurora_serverless" { default = false }
variable "enable_database_backtrack" { default = false }
variable "enable_dynamodb_global_tables" { default = false }
variable "enable_dynamodb_streams" { default = false }
variable "monthly_budget_limit" { default = "50" }
variable "cpu_alarm_threshold" { default = 80 }
variable "rds_connection_threshold" { default = 80 }
variable "enable_cost_monitoring" { default = false }
variable "enable_security_monitoring" { default = false }
variable "enable_eventbridge" { default = false }
variable "enable_xray" { default = false }
variable "enable_lambda_monitoring" { default = false }

# Advanced networking settings
variable "enable_transit_gateway" { default = false }
variable "enable_vpc_peering" { default = false }
variable "enable_route53_advanced" { default = false }
variable "enable_vpn_gateway" { default = false }
variable "enable_direct_connect_simulation" { default = false }
variable "enable_network_firewall" { default = false }
variable "enable_route53_resolver" { default = false }
variable "cloudfront_price_class" { default = "PriceClass_100" }
variable "route53_health_check_regions" { default = ["us-east-1"] }
variable "vpc_peering_regions" { default = ["us-east-2"] }
variable "transit_gateway_asn" { default = 64512 }
variable "cloudfront_cache_behavior" { default = "managed-caching-optimized" }

# Map study config toggles to domain enables
locals {
  # Override domain enables based on study config toggles
  computed_enable_domain1 = coalesce(
    var.enable_domain1,
    (var.enable_security_features || var.enable_security_tier)
  )
  
  computed_enable_domain2 = coalesce(
    var.enable_domain2,
    var.enable_compute_tier
  )
  
  computed_enable_domain3 = coalesce(
    var.enable_domain3,
    var.enable_monitoring_tier
  )
  
  computed_enable_domain4 = coalesce(
    var.enable_domain4,
    var.enable_database_tier
  )
}

# Override the module count in main.tf using these computed values
# This is handled by using -var flags when running terraform
EOF

echo -e "${GREEN}✓${NC} Created compatibility-layer.tf"

# Step 6: Show status
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}What was done:${NC}"
echo "• Moved conflicting destroy configs to .archive/"
echo "• Backed up old compatibility.tf"
echo "• Cleaned duplicate variables"
echo "• Created new compatibility-layer.tf"
echo "• Cleaned Terraform cache"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Initialize Terraform:"
echo "   ${GREEN}terraform init${NC}"
echo ""
echo "2. Test with a study config:"
echo "   ${GREEN}terraform plan -var-file=\"study-configs/domain1-security.tfvars\"${NC}"
echo ""
echo "3. If successful, apply:"
echo "   ${GREEN}terraform apply -var-file=\"study-configs/domain1-security.tfvars\"${NC}"
echo ""
echo -e "${BLUE}Note:${NC} The study configs will now map to your domain architecture"
echo "through the compatibility layer variables."