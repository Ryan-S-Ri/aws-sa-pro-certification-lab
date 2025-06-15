#!/bin/bash
# Simple Fix for Invalid Resource Names
# Fixes specific known issues in compute and database modules

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing Invalid Resource Names (Simple Version)${NC}"
echo "================================================"
echo ""

# Fix compute module
if [ -f "modules/compute/main.tf" ]; then
    echo -e "${YELLOW}Fixing modules/compute/main.tf...${NC}"
    
    # Backup the file
    cp modules/compute/main.tf modules/compute/main.tf.backup
    
    # Fix the specific lines with invalid resource names
    sed -i \
        -e 's/resource "tls_private_key" "${var\.project_name}_key" {/resource "tls_private_key" "main" {/g' \
        -e 's/resource "aws_key_pair" "${var\.project_name}_key" {/resource "aws_key_pair" "main" {/g' \
        modules/compute/main.tf
    
    # Fix references to these resources
    sed -i \
        -e 's/tls_private_key\.${var\.project_name}_key/tls_private_key.main/g' \
        -e 's/aws_key_pair\.${var\.project_name}_key/aws_key_pair.main/g' \
        modules/compute/main.tf
    
    # Fix the key_name reference in the key_name argument
    sed -i \
        -e 's/key_name = "${var\.project_name}_key"/key_name = "${var.project_name}-key"/g' \
        modules/compute/main.tf
    
    echo -e "  ${GREEN}✓${NC} Fixed compute module"
fi

# Fix database module
if [ -f "modules/database/main.tf" ]; then
    echo -e "${YELLOW}Fixing modules/database/main.tf...${NC}"
    
    # Backup the file
    cp modules/database/main.tf modules/database/main.tf.backup
    
    # Fix the specific line with invalid resource name
    sed -i \
        -e 's/resource "aws_dynamodb_table" "${var\.project_name}_table" {/resource "aws_dynamodb_table" "main" {/g' \
        modules/database/main.tf
    
    # Fix references to this resource
    sed -i \
        -e 's/aws_dynamodb_table\.${var\.project_name}_table/aws_dynamodb_table.main/g' \
        modules/database/main.tf
    
    # Fix the table name in the name argument
    sed -i \
        -e 's/name = "${var\.project_name}_table"/name = "${var.project_name}-table"/g' \
        modules/database/main.tf
    
    echo -e "  ${GREEN}✓${NC} Fixed database module"
fi

# Check for any other modules with similar issues
echo -e "\n${BLUE}Checking other modules...${NC}"
for module in modules/*/main.tf; do
    if grep -q 'resource "[^"]*" "${var\.' "$module" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC}  Found potential issues in: $module"
        echo "      Please manually fix resource names that use \${var...}"
    fi
done

# Show what was changed
echo -e "\n${BLUE}Changes made:${NC}"
if [ -f "modules/compute/main.tf.backup" ]; then
    echo -e "\n${YELLOW}Compute module changes:${NC}"
    diff modules/compute/main.tf.backup modules/compute/main.tf || true
    rm modules/compute/main.tf.backup
fi

if [ -f "modules/database/main.tf.backup" ]; then
    echo -e "\n${YELLOW}Database module changes:${NC}"
    diff modules/database/main.tf.backup modules/database/main.tf || true
    rm modules/database/main.tf.backup
fi

echo -e "\n${GREEN}✅ Done!${NC}"
echo ""
echo "Next step: Run ${GREEN}./validate_modules.sh${NC} again"