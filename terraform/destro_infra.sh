#!/bin/bash
# Automated script to destroy old infrastructure and prepare for new configuration

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔄 Destroying Old Infrastructure & Preparing New Configuration${NC}"
echo "============================================================="
echo ""

# Step 1: Check if we need to restore old state first
if [ ! -f "terraform.tfstate" ] && [ -f ".backup_20250614_130034/terraform.tfstate" ]; then
    echo -e "${YELLOW}Step 1: Restoring old state file from backup...${NC}"
    cp .backup_20250614_130034/terraform.tfstate terraform.tfstate
    cp .backup_20250614_130034/terraform.tfstate.backup terraform.tfstate.backup 2>/dev/null || true
    echo -e "${GREEN}✓${NC} State file restored"
else
    echo -e "${GREEN}✓${NC} State file found"
fi

# Step 2: Move current .tf files temporarily
echo -e "\n${YELLOW}Step 2: Moving current .tf files temporarily...${NC}"
if [ ! -d "temp_tf_files" ]; then
    mkdir -p temp_tf_files
    mv *.tf temp_tf_files/ 2>/dev/null || {
        echo -e "${YELLOW}⚠${NC}  No .tf files to move (might already be moved)"
    }
    echo -e "${GREEN}✓${NC} Current .tf files moved to temp_tf_files/"
else
    echo -e "${YELLOW}⚠${NC}  temp_tf_files already exists"
fi

# Step 3: Create the destroy configuration
echo -e "\n${YELLOW}Step 3: Setting up destroy configuration...${NC}"
if [ -f "destroy_old_infrastructure.tf" ]; then
    cp destroy_old_infrastructure.tf main.tf
    echo -e "${GREEN}✓${NC} Copied destroy configuration to main.tf"
else
    # Create it if it doesn't exist
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

# Provider with alias to match state
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# Default provider
provider "aws" {
  region = "us-east-1"
}
EOF
    echo -e "${GREEN}✓${NC} Created destroy configuration"
fi

# Step 4: Initialize terraform
echo -e "\n${YELLOW}Step 4: Initializing Terraform...${NC}"
terraform init -upgrade
echo -e "${GREEN}✓${NC} Terraform initialized"

# Step 5: Show what will be destroyed
echo -e "\n${YELLOW}Step 5: Checking what will be destroyed...${NC}"
echo -e "${BLUE}Running terraform plan -destroy to show what will be removed:${NC}"
echo ""
terraform plan -destroy -out=destroy.tfplan | tee destroy_plan.log

# Step 6: Ask for confirmation
echo -e "\n${RED}⚠️  IMPORTANT: Review the destruction plan above!${NC}"
echo -e "${YELLOW}This will destroy all the resources listed.${NC}"
echo ""
read -p "Do you want to proceed with destroying these resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "\n${YELLOW}Destruction cancelled. You can run this script again later.${NC}"
    echo "To manually proceed:"
    echo "  1. terraform destroy"
    echo "  2. ./restore_new_config.sh"
    exit 0
fi

# Step 7: Destroy infrastructure
echo -e "\n${YELLOW}Step 6: Destroying infrastructure...${NC}"
terraform destroy -auto-approve
echo -e "${GREEN}✓${NC} Infrastructure destroyed"

# Step 8: Clean up and restore new configuration
echo -e "\n${YELLOW}Step 7: Cleaning up and restoring new configuration...${NC}"

# Remove the destroy configuration and state files
rm -f main.tf
rm -f terraform.tfstate*
rm -f destroy.tfplan
rm -f destroy_plan.log
rm -f destroy_old_infrastructure.tf
rm -rf .terraform

# Restore the new configuration
if [ -d "temp_tf_files" ]; then
    mv temp_tf_files/*.tf . 2>/dev/null || true
    rmdir temp_tf_files
    echo -e "${GREEN}✓${NC} New configuration restored"
fi

# Step 9: Initialize with new configuration
echo -e "\n${YELLOW}Step 8: Initializing with new configuration...${NC}"
terraform init
echo -e "${GREEN}✓${NC} Terraform initialized with new configuration"

# Step 10: Validate new configuration
echo -e "\n${YELLOW}Step 9: Validating new configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN}✓${NC} Configuration is valid!"
else
    echo -e "${RED}✗${NC} Configuration has errors. Run ./validate_modules.sh for details"
fi

# Final summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Infrastructure Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}What happened:${NC}"
echo "  • Old infrastructure destroyed"
echo "  • State files cleaned up"
echo "  • New modular configuration restored"
echo "  • Terraform initialized with new config"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review and enable modules in terraform.tfvars"
echo "2. Run: ${GREEN}terraform plan${NC}"
echo "3. Deploy new infrastructure: ${GREEN}terraform apply${NC}"
echo ""
echo -e "${BLUE}Current enabled modules (from terraform.tfvars):${NC}"
grep "^enable_" terraform.tfvars | grep -v "^#" || echo "Check terraform.tfvars"