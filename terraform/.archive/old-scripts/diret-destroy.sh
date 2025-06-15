#!/bin/bash
# Direct fix for destroying infrastructure with provider alias issues

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Direct Destroy Fix${NC}"
echo "=================="
echo ""

# Step 1: Check current situation
echo -e "${YELLOW}Step 1: Checking current state...${NC}"

# Check if we can list state
echo "Attempting to list state resources..."
if terraform state list > state_list.txt 2>&1; then
    resource_count=$(wc -l < state_list.txt)
    echo -e "${RED}Found $resource_count resources in state${NC}"
    echo "First 10 resources:"
    head -10 state_list.txt
    rm state_list.txt
else
    echo -e "${RED}Cannot list state directly${NC}"
fi

# Step 2: Create minimal destroy configuration
echo -e "\n${YELLOW}Step 2: Creating destroy configuration...${NC}"

# Backup current files
mkdir -p .backup_before_destroy
mv *.tf .backup_before_destroy/ 2>/dev/null || true

# Create destroy-only configuration
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

# Provider with primary alias - REQUIRED FOR YOUR STATE
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}
EOF

echo -e "${GREEN}✓${NC} Created minimal destroy configuration"

# Step 3: Try to destroy
echo -e "\n${YELLOW}Step 3: Attempting destroy...${NC}"
echo -e "${BLUE}Running: terraform destroy -auto-approve${NC}"
echo ""

terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ SUCCESS! Infrastructure destroyed!${NC}"
    
    # Clean up
    rm -f terraform.tfstate*
    rm -rf .terraform
    
    # Restore original files
    echo -e "\n${YELLOW}Restoring original configuration...${NC}"
    mv .backup_before_destroy/*.tf . 2>/dev/null || true
    mv .backup_before_destroy/terraform.tfvars . 2>/dev/null || true
    rm -rf .backup_before_destroy
    
    # Initialize fresh
    terraform init
    
    echo -e "\n${GREEN}✅ You're ready to start fresh!${NC}"
    echo "Next: terraform plan"
else
    echo -e "\n${RED}❌ Destroy failed${NC}"
    echo -e "\n${YELLOW}Try Option B: Force remove from state${NC}"
    echo ""
    echo "Run this command to remove ALL resources from state:"
    echo -e "${RED}terraform state list | xargs -n1 terraform state rm${NC}"
    echo ""
    echo "This will orphan resources in AWS but let you start fresh."
fi
