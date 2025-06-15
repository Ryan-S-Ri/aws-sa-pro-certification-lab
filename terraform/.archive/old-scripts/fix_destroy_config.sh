#!/bin/bash
# Fix the destroy configuration with proper provider setup

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing Provider Configuration for Destroy${NC}"
echo "==========================================="
echo ""

# Create the correct main.tf with proper provider configuration
echo -e "${YELLOW}Creating corrected destroy configuration...${NC}"

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

# Primary provider (what the old state expects)
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# Module configurations with proper provider mapping
module "networking" {
  source = "./modules/networking"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  # Dummy variables to satisfy module requirements
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
}

module "security" {
  source = "./modules/security"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
  vpc_id       = ""
}

module "compute" {
  source = "./modules/compute"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
  vpc_id       = ""
  subnet_ids   = []
}

module "database" {
  source = "./modules/database"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
  vpc_id       = ""
  subnet_ids   = []
}

module "storage" {
  source = "./modules/storage"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
}

module "serverless" {
  source = "./modules/serverless"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = 0
  
  providers = {
    aws         = aws
    aws.primary = aws.primary
  }
  
  project_name = "lab"
  environment  = "dev"
  common_tags  = {}
}
EOF

echo -e "${GREEN}✓${NC} Created corrected main.tf"

# Now initialize and destroy
echo -e "\n${YELLOW}Initializing Terraform...${NC}"
rm -rf .terraform
terraform init -upgrade

echo -e "\n${YELLOW}Creating destroy plan...${NC}"
terraform plan -destroy -out=destroy.tfplan

echo -e "\n${RED}Review the plan above carefully!${NC}"
echo "This will destroy all the resources listed."
echo ""
read -p "Type 'DESTROY' to proceed with destruction: " confirm

if [ "$confirm" != "DESTROY" ]; then
    echo -e "\n${YELLOW}Destruction cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Destroying infrastructure...${NC}"
terraform apply destroy.tfplan

echo -e "\n${GREEN}✅ Infrastructure destroyed!${NC}"

# Clean up
echo -e "\n${YELLOW}Cleaning up...${NC}"
rm -f terraform.tfstate*
rm -f destroy.tfplan
rm -rf .terraform

# Restore new configuration
echo -e "\n${YELLOW}Restoring new configuration...${NC}"
if [ -d "new_config_backup" ]; then
    rm -f main.tf variables.tf
    cp new_config_backup/*.tf . 2>/dev/null || true
    cp new_config_backup/terraform.tfvars . 2>/dev/null || true
fi

# Remove provider.tf files from modules
for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        rm -f "$module_dir/providers.tf"
    fi
done

echo -e "${GREEN}✓${NC} Configuration restored"

# Initialize with clean state
terraform init

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Ready for Fresh Deployment!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. ${GREEN}terraform validate${NC}"
echo "2. ${GREEN}terraform plan${NC}"
echo "3. ${GREEN}terraform apply${NC}"