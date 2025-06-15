#!/bin/bash
# Fix duplicate provider configuration issues

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing Duplicate Provider Configuration${NC}"
echo "=========================================="
echo ""

# Check for leftover destroy configuration files
echo -e "${YELLOW}Looking for leftover configuration files...${NC}"

if [ -f "destroy_old_infrastructure.tf" ]; then
    echo -e "${RED}Found: destroy_old_infrastructure.tf${NC}"
    rm -f destroy_old_infrastructure.tf
    echo -e "${GREEN}✓${NC} Removed destroy_old_infrastructure.tf"
fi

if [ -f "destroy_old_infrastructure.sh" ]; then
    echo -e "${YELLOW}Found: destroy_old_infrastructure.sh${NC}"
    mv destroy_old_infrastructure.sh .old_scripts/ 2>/dev/null || {
        mkdir -p .old_scripts
        mv destroy_old_infrastructure.sh .old_scripts/
    }
    echo -e "${GREEN}✓${NC} Moved destroy script to .old_scripts/"
fi

# Check for any other potential duplicate files
for file in destroy*.tf comprehensive*.tf; do
    if [ -f "$file" ]; then
        echo -e "${YELLOW}Found: $file${NC}"
        rm -f "$file"
        echo -e "${GREEN}✓${NC} Removed $file"
    fi
done

# Clean up other temporary files
if [ -f "handle_orphaned_resources.sh" ]; then
    rm -f handle_orphaned_resources.sh
    echo -e "${GREEN}✓${NC} Removed handle_orphaned_resources.sh"
fi

if [ -f "restore_new_configuration.sh" ]; then
    mv restore_new_configuration.sh .old_scripts/ 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Moved restore script to .old_scripts/"
fi

# Verify we only have the correct .tf files
echo -e "\n${BLUE}Current .tf files:${NC}"
ls -la *.tf 2>/dev/null || echo "No .tf files found in root"

echo -e "\n${BLUE}Expected files:${NC}"
echo "  - main.tf"
echo "  - variables.tf"
echo "  - outputs.tf"
echo "  - terraform.tfvars"

# Re-initialize Terraform
echo -e "\n${YELLOW}Re-initializing Terraform...${NC}"
rm -rf .terraform
terraform init

# Validate configuration
echo -e "\n${YELLOW}Validating configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN}✅ Configuration is valid!${NC}"
    
    # Show current module status
    echo -e "\n${BLUE}Current module status from terraform.tfvars:${NC}"
    grep "^enable_" terraform.tfvars | while read line; do
        if [[ $line == *"true"* ]]; then
            echo -e "  ${GREEN}✓${NC} $line"
        else
            echo -e "  ${YELLOW}○${NC} $line"
        fi
    done
    
    echo -e "\n${GREEN}Ready to proceed!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Check your modules: ${GREEN}ls modules/${NC}"
    echo "2. Review module content: ${GREEN}cat modules/networking/main.tf${NC}"
    echo "3. Plan deployment: ${GREEN}terraform plan${NC}"
    echo "4. Enable modules as needed in: ${GREEN}terraform.tfvars${NC}"
else
    echo -e "${RED}✗ Validation failed${NC}"
    echo "Check the errors above"
fi

# Final cleanup check
echo -e "\n${BLUE}Cleanup summary:${NC}"
echo "- Removed leftover destroy configuration files"
echo "- Moved utility scripts to .old_scripts/"
echo "- Re-initialized Terraform"
echo "- Configuration validated"

if [ -d ".old_scripts" ]; then
    echo -e "\n${YELLOW}Note:${NC} Old scripts saved in .old_scripts/ directory"
fi