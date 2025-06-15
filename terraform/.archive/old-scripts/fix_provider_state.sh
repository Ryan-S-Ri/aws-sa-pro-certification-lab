#!/bin/bash
# Fix Provider Configuration and State Issues
# This handles existing terraform state with provider alias issues

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}⚠️  IMPORTANT: Existing Infrastructure Detected${NC}"
echo "==========================================="
echo ""
echo "You have existing infrastructure in your Terraform state that was"
echo "created with a provider alias configuration. We need to handle this carefully."
echo ""

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No terraform.tfstate found in current directory.${NC}"
    echo "Looking for state files..."
    find . -name "terraform.tfstate" -type f 2>/dev/null | head -5
fi

echo -e "\n${BLUE}Choose how to proceed:${NC}"
echo "1. DESTROY existing infrastructure first (RECOMMENDED for lab/test)"
echo "2. Fix provider configuration to match existing state"
echo "3. Migrate state to new configuration (ADVANCED)"
echo "4. Start completely fresh (DELETE state - DANGEROUS)"
echo ""
read -p "Select option (1-4): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Option 1: Destroy existing infrastructure${NC}"
        echo "========================================"
        
        # Create a temporary main.tf with the old provider configuration
        cat > destroy_old_infrastructure.tf << 'EOF'
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
        
        echo -e "${GREEN}✓${NC} Created destroy_old_infrastructure.tf"
        echo ""
        echo -e "${YELLOW}Steps to destroy old infrastructure:${NC}"
        echo "1. Move your current .tf files temporarily:"
        echo "   ${GREEN}mkdir temp_tf_files && mv *.tf temp_tf_files/${NC}"
        echo ""
        echo "2. Copy the destroy configuration:"
        echo "   ${GREEN}cp destroy_old_infrastructure.tf main.tf${NC}"
        echo ""
        echo "3. Initialize and destroy:"
        echo "   ${GREEN}terraform init${NC}"
        echo "   ${GREEN}terraform destroy${NC}"
        echo ""
        echo "4. After successful destroy, restore new configuration:"
        echo "   ${GREEN}rm main.tf terraform.tfstate*${NC}"
        echo "   ${GREEN}mv temp_tf_files/*.tf .${NC}"
        echo "   ${GREEN}rmdir temp_tf_files${NC}"
        echo ""
        echo "5. Initialize with new configuration:"
        echo "   ${GREEN}terraform init${NC}"
        ;;
        
    2)
        echo -e "\n${YELLOW}Option 2: Fix provider configuration${NC}"
        echo "===================================="
        
        # Update main.tf to include provider alias
        echo -e "${BLUE}Updating main.tf with provider alias...${NC}"
        
        # Backup current main.tf
        cp main.tf main.tf.backup-provider-fix
        
        # Insert provider alias after the existing provider
        sed -i '/provider "aws" {/,/^}/a\
\
# Provider with alias to match existing state\
provider "aws" {\
  alias  = "primary"\
  region = var.aws_region\
  \
  default_tags {\
    tags = var.common_tags\
  }\
}' main.tf
        
        # Update all modules to use the provider alias
        echo -e "${BLUE}Updating modules to use provider alias...${NC}"
        
        for module_dir in modules/*; do
            if [ -d "$module_dir" ] && [ -f "$module_dir/main.tf" ]; then
                module_name=$(basename "$module_dir")
                
                # Add provider requirement to module
                cat > "$module_dir/providers.tf" << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.primary]
    }
  }
}
EOF
                echo -e "  ${GREEN}✓${NC} Added provider configuration to $module_name"
            fi
        done
        
        # Update module calls in main.tf to pass provider
        sed -i '/module "/{
            n
            /source.*modules/a\  providers = {\
    aws         = aws\
    aws.primary = aws.primary\
  }
        }' main.tf
        
        echo -e "${GREEN}✓${NC} Updated provider configuration"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. ${GREEN}terraform init -upgrade${NC}"
        echo "2. ${GREEN}terraform plan${NC}"
        echo "3. If plan looks good: ${GREEN}terraform apply${NC}"
        ;;
        
    3)
        echo -e "\n${YELLOW}Option 3: State migration${NC}"
        echo "========================"
        
        # Create state migration script
        cat > migrate_state.sh << 'EOF'
#!/bin/bash
# State Migration Script

echo "Migrating Terraform state to new configuration..."

# First, backup the current state
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)

# Remove provider aliases from state
echo "Removing provider aliases from state..."
terraform state replace-provider 'registry.terraform.io/hashicorp/aws.primary' 'registry.terraform.io/hashicorp/aws'

echo "State migration complete!"
echo "Run 'terraform init' to continue."
EOF
        
        chmod +x migrate_state.sh
        
        echo -e "${GREEN}✓${NC} Created migrate_state.sh"
        echo ""
        echo -e "${YELLOW}To migrate state:${NC}"
        echo "1. ${GREEN}./migrate_state.sh${NC}"
        echo "2. ${GREEN}terraform init${NC}"
        echo "3. ${GREEN}terraform plan${NC}"
        echo ""
        echo -e "${RED}WARNING:${NC} This is advanced. Make sure you have backups!"
        ;;
        
    4)
        echo -e "\n${RED}Option 4: DELETE STATE (DANGEROUS)${NC}"
        echo "=================================="
        echo ""
        echo -e "${RED}WARNING: This will orphan all existing resources!${NC}"
        echo "They will continue to exist in AWS but Terraform will lose track of them."
        echo ""
        read -p "Are you SURE you want to delete state? Type 'DELETE STATE' to confirm: " confirm
        
        if [ "$confirm" = "DELETE STATE" ]; then
            # Backup state files first
            mkdir -p .state_backup
            mv terraform.tfstate* .state_backup/ 2>/dev/null || true
            rm -rf .terraform
            
            echo -e "${GREEN}✓${NC} State files moved to .state_backup/"
            echo -e "${GREEN}✓${NC} Terraform directory cleaned"
            echo ""
            echo "You can now run:"
            echo "  ${GREEN}terraform init${NC}"
            echo "  ${GREEN}terraform plan${NC}"
            echo ""
            echo -e "${RED}Remember:${NC} Your old resources still exist in AWS!"
        else
            echo "Cancelled. State files were NOT deleted."
        fi
        ;;
        
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac

# Also fix the storage module resource naming issue
if [ -f "modules/storage/main.tf" ]; then
    echo -e "\n${BLUE}Fixing storage module resource names...${NC}"
    sed -i \
        -e 's/resource "aws_s3_bucket" "${var\.project_name}_bucket"/resource "aws_s3_bucket" "main"/g' \
        -e 's/resource "random_string" "${var\.project_name}_bucket_suffix"/resource "random_string" "bucket_suffix"/g' \
        modules/storage/main.tf
    echo -e "${GREEN}✓${NC} Fixed storage module"
fi

echo -e "\n${BLUE}Summary:${NC}"
echo "========="
echo "You have existing infrastructure that needs to be handled before"
echo "you can use the new modular configuration. Choose the option that"
echo "best fits your situation:"
echo ""
echo "- For lab/test environments: Option 1 (destroy and rebuild)"
echo "- For production: Option 2 (fix provider) or Option 3 (migrate)"
echo "- Only use Option 4 if you're okay with orphaned resources"