#!/bin/bash
# Create comprehensive destroy configuration with all provider aliases

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Creating Comprehensive Destroy Configuration${NC}"
echo "=============================================="
echo ""

# Create a comprehensive main.tf with all provider aliases
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider
provider "aws" {
  region = "us-east-1"
}

# Provider with primary alias (for most resources)
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# Provider with networking alias (for networking VPC)
provider "aws" {
  alias  = "networking"
  region = "us-east-1"
}

# Provider with testbed alias (for testbed VPC)
provider "aws" {
  alias  = "testbed"
  region = "us-east-1"
}

# Add empty variable blocks to suppress warnings
variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "lab"
}

variable "enable_networking" {
  default = true
}

variable "enable_security" {
  default = true
}

variable "enable_compute" {
  default = false
}

variable "enable_database" {
  default = false
}

variable "enable_storage" {
  default = false
}

variable "enable_serverless" {
  default = false
}

variable "enable_monitoring" {
  default = false
}

variable "enable_web_sg" {
  default = true
}

variable "enable_database_sg" {
  default = false
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  default = false
}

variable "enable_detailed_monitoring" {
  default = false
}

variable "alarm_email" {
  default = ""
}

variable "enable_versioning" {
  default = true
}

variable "enable_encryption" {
  default = true
}

variable "common_tags" {
  default = {
    Terraform   = "true"
    Environment = "lab"
  }
}
EOF

echo -e "${GREEN}✓${NC} Created comprehensive destroy configuration"

# Now attempt to import orphaned resources or remove them from state
echo -e "\n${YELLOW}Handling orphaned resources...${NC}"

# Create a script to handle orphaned resources
cat > handle_orphaned_resources.sh << 'SCRIPT'
#!/bin/bash

# List all resources in state
echo "Current resources in state:"
terraform state list

# Try to remove orphaned resources from state
echo ""
echo "Attempting to handle orphaned resources..."

# Function to safely remove orphaned resources
remove_orphaned() {
    local resource=$1
    echo "Removing orphaned resource: $resource"
    terraform state rm "$resource" 2>/dev/null || echo "  Already removed or not found"
}

# Remove known orphaned resources
for resource in $(terraform state list | grep "(orphan)"); do
    remove_orphaned "$resource"
done

echo ""
echo "Remaining resources:"
terraform state list
SCRIPT

chmod +x handle_orphaned_resources.sh

echo -e "${GREEN}✓${NC} Created orphaned resource handler script"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Initialize with new configuration:"
echo "   ${GREEN}terraform init -upgrade${NC}"
echo ""
echo "2. Handle orphaned resources:"
echo "   ${GREEN}./handle_orphaned_resources.sh${NC}"
echo ""
echo "3. Try destroy again:"
echo "   ${GREEN}terraform destroy -auto-approve${NC}"
echo ""
echo "4. If destroy succeeds, continue with:"
echo "   ${GREEN}./restore_new_configuration.sh${NC}"

# Create restoration script
cat > restore_new_configuration.sh << 'RESTORE'
#!/bin/bash

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Restoring New Configuration${NC}"
echo "==========================="

# Clean up
rm -f main.tf
rm -f terraform.tfstate*
rm -f handle_orphaned_resources.sh
rm -rf .terraform

# Restore new configuration
if [ -d "temp_tf_files" ]; then
    mv temp_tf_files/*.tf . 2>/dev/null || true
    rmdir temp_tf_files
    echo -e "${GREEN}✓${NC} New configuration restored"
fi

# Initialize
terraform init
echo -e "${GREEN}✓${NC} Terraform initialized"

# Validate
if terraform validate; then
    echo -e "${GREEN}✓${NC} Configuration is valid!"
else
    echo -e "${YELLOW}⚠${NC} Configuration has validation errors"
fi

echo ""
echo -e "${GREEN}Ready to deploy new infrastructure!${NC}"
echo "Next: terraform plan"
RESTORE

chmod +x restore_new_configuration.sh

echo -e "\n${BLUE}Alternative Option:${NC}"
echo "================================"
echo "If you continue to have issues with orphaned resources,"
echo "you can force remove ALL resources from state and manually"
echo "clean up in AWS Console:"
echo ""
echo "  ${RED}terraform state rm \$(terraform state list)${NC}"
echo ""
echo "This will orphan ALL resources but allow you to start fresh."