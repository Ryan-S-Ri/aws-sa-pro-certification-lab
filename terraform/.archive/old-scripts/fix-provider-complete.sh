#!/bin/bash
# Complete fix for provider configuration state issues
# This handles the module.*.provider["..."].primary mismatch

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing Provider Configuration State Issues${NC}"
echo "============================================"
echo ""

# Step 1: Check current state
echo -e "${YELLOW}Step 1: Checking current state...${NC}"
if [ -f "terraform.tfstate" ]; then
    resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
    echo -e "Found ${RED}$resource_count${NC} resources in state"
    
    if [ "$resource_count" -gt 0 ]; then
        echo -e "\n${YELLOW}Resources by module:${NC}"
        terraform state list | grep -E "^module\." | cut -d. -f2 | sort | uniq -c || true
    fi
else
    echo -e "${GREEN}✓${NC} No existing state file found - starting fresh!"
    exit 0
fi

# Step 2: Create proper destroy configuration
echo -e "\n${YELLOW}Step 2: Creating destroy configuration with proper providers...${NC}"

# Backup current files
mkdir -p .backup_configs
cp *.tf .backup_configs/ 2>/dev/null || true
cp terraform.tfvars .backup_configs/ 2>/dev/null || true

# Create destroy configuration
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
  region = var.aws_region
}

# Primary provider - matches what's in the state
provider "aws" {
  alias  = "primary"
  region = var.aws_region
}

# Variables required by modules
variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "lab"
}

variable "environment" {
  default = "dev"
}

variable "common_tags" {
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Module configurations with count = 0 to destroy
module "networking" {
  source = "./modules/networking"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
}

module "security" {
  source = "./modules/security"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
  vpc_id       = ""
}

module "compute" {
  source = "./modules/compute"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
  vpc_id       = ""
  subnet_ids   = []
}

module "database" {
  source = "./modules/database"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
  vpc_id       = ""
  subnet_ids   = []
}

module "storage" {
  source = "./modules/storage"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
}

module "serverless" {
  source = "./modules/serverless"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = 0
  
  providers = {
    aws = aws.primary
  }
  
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
}
EOF

echo -e "${GREEN}✓${NC} Created destroy configuration"

# Step 3: Add provider configuration to modules
echo -e "\n${YELLOW}Step 3: Adding provider configuration to modules...${NC}"

for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        cat > "$module_dir/providers.tf" << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws]
    }
  }
}
EOF
        echo -e "${GREEN}✓${NC} Added provider config to $(basename $module_dir)"
    fi
done

# Step 4: Initialize and plan destroy
echo -e "\n${YELLOW}Step 4: Initializing Terraform...${NC}"
rm -rf .terraform
terraform init -upgrade

echo -e "\n${YELLOW}Step 5: Planning destroy operation...${NC}"
terraform plan -destroy -out=destroy.tfplan > destroy_plan.log 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Destroy plan created successfully"
    
    # Show summary
    echo -e "\n${BLUE}Resources to be destroyed:${NC}"
    grep -E "will be destroyed|to destroy" destroy_plan.log | head -20 || true
    
    echo -e "\n${RED}⚠️  WARNING: This will destroy all resources!${NC}"
    echo "Review the full plan in destroy_plan.log"
    echo ""
    read -p "Type 'DESTROY' to proceed with destruction: " confirm
    
    if [ "$confirm" = "DESTROY" ]; then
        echo -e "\n${YELLOW}Destroying infrastructure...${NC}"
        terraform apply destroy.tfplan
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Infrastructure destroyed successfully!${NC}"
            
            # Clean up
            rm -f terraform.tfstate*
            rm -f destroy.tfplan
            rm -f destroy_plan.log
            rm -rf .terraform
            
            # Restore original configuration
            echo -e "\n${YELLOW}Restoring original configuration...${NC}"
            rm -f main.tf
            cp .backup_configs/*.tf . 2>/dev/null || true
            cp .backup_configs/terraform.tfvars . 2>/dev/null || true
            
            # Remove provider files from modules
            for module_dir in modules/*; do
                rm -f "$module_dir/providers.tf" 2>/dev/null || true
            done
            
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
        else
            echo -e "${RED}❌ Destroy failed. Check errors above.${NC}"
        fi
    else
        echo "Destroy cancelled."
    fi
else
    echo -e "${RED}❌ Failed to create destroy plan${NC}"
    echo "Errors:"
    tail -20 destroy_plan.log
    
    echo -e "\n${YELLOW}Alternative: Nuclear Option${NC}"
    echo "If you can't destroy normally, you can:"
    echo "1. Remove all resources from state (orphaning them in AWS)"
    echo "2. Manually clean up in AWS Console"
    echo ""
    echo "Run: ${RED}./nuke.sh${NC} for the nuclear option"
fi

# Create a cleanup verification script
cat > verify_cleanup.sh << 'VERIFY'
#!/bin/bash
# Verify cleanup was successful

echo "🔍 Verifying Cleanup"
echo "==================="

# Check state
if [ -f "terraform.tfstate" ]; then
    count=$(terraform state list 2>/dev/null | wc -l || echo "0")
    if [ "$count" -eq "0" ]; then
        echo "✓ State is empty"
    else
        echo "❌ State still contains $count resources"
        terraform state list | head -10
    fi
else
    echo "✓ No state file exists"
fi

# Check configuration
if terraform validate >/dev/null 2>&1; then
    echo "✓ Configuration is valid"
else
    echo "❌ Configuration has errors"
fi

# Check for leftover provider files
leftovers=0
for module_dir in modules/*; do
    if [ -f "$module_dir/providers.tf" ]; then
        echo "⚠️  Found leftover providers.tf in $(basename $module_dir)"
        ((leftovers++))
    fi
done

if [ $leftovers -eq 0 ]; then
    echo "✓ No leftover provider files"
fi

echo ""
echo "Ready for fresh deployment: $( [ "$count" -eq "0" ] && [ $leftovers -eq 0 ] && echo "YES ✓" || echo "NO ❌" )"
VERIFY

chmod +x verify_cleanup.sh

echo -e "\n${BLUE}Created verification script: ${GREEN}./verify_cleanup.sh${NC}"