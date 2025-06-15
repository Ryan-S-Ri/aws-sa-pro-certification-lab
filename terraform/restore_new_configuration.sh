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
