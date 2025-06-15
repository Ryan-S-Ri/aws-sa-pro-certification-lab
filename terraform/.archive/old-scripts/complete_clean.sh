#!/bin/bash
# Complete cleanup of old infrastructure with provider aliases

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}⚠️  CRITICAL: Old Infrastructure Still Exists${NC}"
echo "============================================"
echo ""
echo "We need to properly destroy the old infrastructure before proceeding."
echo ""

# Step 1: Move current files to safety
echo -e "${YELLOW}Step 1: Preserving current configuration...${NC}"
if [ ! -d "new_config_backup" ]; then
    mkdir -p new_config_backup
    cp *.tf new_config_backup/ 2>/dev/null || true
    cp terraform.tfvars new_config_backup/ 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Current configuration backed up to new_config_backup/"
fi

# Step 2: Create comprehensive destroy configuration
echo -e "\n${YELLOW}Step 2: Creating destroy configuration with provider alias...${NC}"

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

# Empty module configurations to satisfy state
module "networking" {
  source = "./modules/networking"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "security" {
  source = "./modules/security"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "compute" {
  source = "./modules/compute"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "database" {
  source = "./modules/database"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "storage" {
  source = "./modules/storage"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "serverless" {
  source = "./modules/serverless"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = 0
  providers = {
    aws = aws.primary
  }
}
EOF

# Step 3: Update each module to accept the provider
echo -e "\n${YELLOW}Step 3: Updating modules to accept provider alias...${NC}"

for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        # Create a temporary provider configuration for each module
        cat > "$module_dir/providers.tf" << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws, aws.primary]
    }
  }
}
EOF
        echo -e "${GREEN}✓${NC} Updated $(basename $module_dir) module"
    fi
done

# Step 4: Create variables file to suppress warnings
echo -e "\n${YELLOW}Step 4: Creating minimal variables...${NC}"
cat > variables.tf << 'EOF'
# Minimal variables to suppress warnings during destroy
variable "project_name" {
  default = "lab"
}

variable "environment" {
  default = "dev"
}

variable "common_tags" {
  default = {}
}

variable "vpc_id" {
  default = ""
}

variable "subnet_ids" {
  default = []
}
EOF

# Step 5: Initialize Terraform
echo -e "\n${YELLOW}Step 5: Initializing Terraform...${NC}"
rm -rf .terraform
terraform init -upgrade

# Step 6: Create destroy plan
echo -e "\n${YELLOW}Step 6: Creating destroy plan...${NC}"
echo -e "${BLUE}This will show all resources that will be destroyed:${NC}"
terraform plan -destroy -out=destroy.tfplan

# Step 7: Ask for confirmation
echo -e "\n${RED}⚠️  FINAL WARNING${NC}"
echo "=================="
echo "This will destroy ALL resources shown above."
echo "Make sure you have reviewed the plan carefully."
echo ""
read -p "Type 'DESTROY ALL' to proceed with destruction: " confirm

if [ "$confirm" != "DESTROY ALL" ]; then
    echo -e "\n${YELLOW}Destruction cancelled.${NC}"
    exit 0
fi

# Step 8: Destroy everything
echo -e "\n${YELLOW}Step 8: Destroying all infrastructure...${NC}"
terraform destroy -auto-approve

# Step 9: Clean up state
echo -e "\n${YELLOW}Step 9: Cleaning up...${NC}"
rm -f terraform.tfstate*
rm -f destroy.tfplan
rm -rf .terraform

# Step 10: Restore new configuration
echo -e "\n${YELLOW}Step 10: Restoring new configuration...${NC}"
rm -f main.tf variables.tf
cp new_config_backup/*.tf . 2>/dev/null || true
cp new_config_backup/terraform.tfvars . 2>/dev/null || true

# Remove provider.tf files from modules
for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        rm -f "$module_dir/providers.tf"
    fi
done

echo -e "${GREEN}✓${NC} New configuration restored"

# Step 11: Initialize with clean state
echo -e "\n${YELLOW}Step 11: Initializing with clean state...${NC}"
terraform init

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Infrastructure Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Status:${NC}"
echo "  • All old infrastructure destroyed"
echo "  • State cleaned up"
echo "  • New configuration restored"
echo "  • Ready for fresh deployment"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Validate: ${GREEN}terraform validate${NC}"
echo "2. Plan: ${GREEN}terraform plan${NC}"
echo "3. Deploy: ${GREEN}terraform apply${NC}"

# Create a fallback script in case something goes wrong
cat > emergency_state_cleanup.sh << 'EMERGENCY'
#!/bin/bash
# Emergency state cleanup - use only if the normal process fails

echo "EMERGENCY STATE CLEANUP"
echo "======================"
echo "This will remove ALL resources from state without destroying them."
echo "Resources will be orphaned in AWS and need manual cleanup."
echo ""
read -p "Type 'EMERGENCY CLEANUP' to proceed: " confirm

if [ "$confirm" = "EMERGENCY CLEANUP" ]; then
    # List all resources
    resources=$(terraform state list)
    
    # Remove each resource from state
    for resource in $resources; do
        echo "Removing $resource from state..."
        terraform state rm "$resource" || true
    done
    
    echo "State cleaned. Resources are orphaned in AWS."
    echo "Manual cleanup required in AWS Console."
else
    echo "Cancelled."
fi
EMERGENCY

chmod +x emergency_state_cleanup.sh

echo -e "\n${YELLOW}Note:${NC} If the destroy process fails, you can use:"
echo "  ${RED}./emergency_state_cleanup.sh${NC} (last resort - orphans resources)