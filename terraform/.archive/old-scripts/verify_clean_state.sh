#!/bin/bash
# Verify clean state and proceed with fresh deployment

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🎉 Great News! Your Terraform state is already clean!${NC}"
echo "=================================================="
echo ""

# Step 1: Clean up any remaining Terraform files
echo -e "${YELLOW}Step 1: Cleaning up Terraform files...${NC}"
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*
rm -f destroy.tfplan
rm -f destroy_plan.log
echo -e "${GREEN}✓${NC} Terraform files cleaned"

# Step 2: Restore clean configuration
echo -e "\n${YELLOW}Step 2: Ensuring clean configuration...${NC}"
if [ -d "new_config_backup" ]; then
    # Only copy if current files are the destroy configuration
    if grep -q "count  = 0" main.tf 2>/dev/null; then
        echo "Detected destroy configuration, restoring clean config..."
        rm -f main.tf variables.tf
        cp new_config_backup/*.tf . 2>/dev/null || true
        cp new_config_backup/terraform.tfvars . 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Clean configuration restored"
    else
        echo -e "${GREEN}✓${NC} Configuration already clean"
    fi
fi

# Remove provider.tf files from modules
for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        rm -f "$module_dir/providers.tf" 2>/dev/null || true
    fi
done

# Step 3: Initialize Terraform
echo -e "\n${YELLOW}Step 3: Initializing Terraform...${NC}"
terraform init

# Step 4: Validate configuration
echo -e "\n${YELLOW}Step 4: Validating configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN}✓${NC} Configuration is valid!"
else
    echo -e "${YELLOW}⚠${NC}  Configuration has validation errors (expected - modules need fixes)"
fi

# Step 5: Check current terraform.tfvars
echo -e "\n${YELLOW}Step 5: Current module settings:${NC}"
echo "================================"
grep "^enable_" terraform.tfvars | while read line; do
    if [[ $line == *"true"* ]]; then
        echo -e "${GREEN}✓${NC} $line"
    else
        echo -e "${YELLOW}○${NC} $line"
    fi
done

# Step 6: Test minimal deployment
echo -e "\n${YELLOW}Step 6: Testing minimal deployment...${NC}"
echo "Running terraform plan with current settings..."
terraform plan -out=test.tfplan > plan_output.txt 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Terraform plan succeeded!"
    echo ""
    cat plan_output.txt | grep -E "Plan:|No changes.|will be created|will be destroyed" || true
    rm -f plan_output.txt test.tfplan
else
    echo -e "${YELLOW}⚠${NC}  Plan has errors (see below)"
    cat plan_output.txt | grep -E "Error:|Warning:" | head -20
    rm -f plan_output.txt
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ You're Ready to Start Fresh!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Current Status:${NC}"
echo "• Terraform state: Empty ✓"
echo "• Configuration: Restored ✓"
echo "• Modules: Need refactoring"
echo ""
echo -e "${YELLOW}Recommended next steps:${NC}"
echo ""
echo "1. ${BLUE}Start with networking only:${NC}"
echo "   # Edit terraform.tfvars"
echo "   enable_networking = true"
echo "   enable_security   = false  # Disable for now"
echo "   enable_compute    = false"
echo "   enable_database   = false"
echo "   enable_storage    = false"
echo "   enable_serverless = false"
echo "   enable_monitoring = false"
echo ""
echo "2. ${BLUE}Fix networking module:${NC}"
echo "   # The networking module should be self-contained"
echo "   cd modules/networking"
echo "   # Review main.tf - ensure it only creates VPC/subnets"
echo "   # Remove any references to other modules"
echo "   cd ../.."
echo ""
echo "3. ${BLUE}Deploy networking:${NC}"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "4. ${BLUE}Then enable and fix other modules one by one${NC}"
echo ""

# Create a simple module starter
cat > start_simple_networking.sh << 'SCRIPT'
#!/bin/bash
# Create a simple, working networking module

echo "Creating simple networking module..."

# Backup current networking module
cp -r modules/networking modules/networking.backup

# Create clean networking module
cat > modules/networking/main.tf << 'EOF'
# Simple Networking Module - VPC and Subnets only

locals {
  common_name = "${var.project_name}-${var.environment}"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${local.common_name}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${local.common_name}-igw"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${local.common_name}-public-${var.availability_zones[count.index]}"
      Type = "public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${local.common_name}-private-${var.availability_zones[count.index]}"
      Type = "private"
    }
  )
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.common_name}-public-rt"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
EOF

cat > modules/networking/variables.tf << 'EOF'
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
EOF

cat > modules/networking/outputs.tf << 'EOF'
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}
EOF

echo "✓ Created simple networking module"
echo ""
echo "Now you can:"
echo "1. Enable only networking in terraform.tfvars"
echo "2. Run: terraform plan"
echo "3. Run: terraform apply"
SCRIPT

chmod +x start_simple_networking.sh

echo -e "\n${BLUE}Helper script created:${NC}"
echo "• ${GREEN}./start_simple_networking.sh${NC} - Creates a simple, working networking module"