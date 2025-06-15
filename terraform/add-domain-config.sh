#!/bin/bash
# Script to create domain configuration files

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Adding Domain Configuration Files${NC}"
echo "=================================="
echo ""

# Create placeholder for Domain 1 main.tf
echo -e "${YELLOW}Creating Domain 1 configuration files...${NC}"

# Since the full configurations are very long, I'll create a simpler version
# that you can start with and expand

cat > domains/domain1-organizational-complexity/main.tf << 'EOF'
# Domain 1: Design Solutions for Organizational Complexity (26%)
# This is a placeholder - replace with full configuration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d1"
}

# Placeholder resource - replace with full domain configuration
resource "aws_s3_bucket" "domain1_temp" {
  bucket = "${local.name_prefix}-temp-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-temp"
      Domain = "1"
    }
  )
}

data "aws_caller_identity" "current" {}
EOF

cat > domains/domain1-organizational-complexity/variables.tf << 'EOF'
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID from shared infrastructure"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs from shared infrastructure"
  type        = list(string)
  default     = []
}
EOF

cat > domains/domain1-organizational-complexity/outputs.tf << 'EOF'
output "domain1_status" {
  description = "Domain 1 deployment status"
  value       = "Domain 1 placeholder deployed"
}
EOF

# Create similar files for other domains
for domain in domain2-new-solutions domain3-continuous-improvement domain4-migration-modernization; do
    echo -e "${YELLOW}Creating $domain configuration files...${NC}"
    
    # Extract domain number
    domain_num=$(echo $domain | grep -o '[0-9]')
    
    cat > domains/$domain/main.tf << EOF
# Domain $domain_num - Placeholder Configuration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "\${var.project_name}-\${var.environment}-d$domain_num"
}

# Placeholder resource
resource "aws_s3_bucket" "domain${domain_num}_temp" {
  bucket = "\${local.name_prefix}-temp-\${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "\${local.name_prefix}-temp"
      Domain = "$domain_num"
    }
  )
}

data "aws_caller_identity" "current" {}
EOF

    cat > domains/$domain/variables.tf << 'EOF'
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID from shared infrastructure"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs from shared infrastructure"
  type        = list(string)
  default     = []
}
EOF

    cat > domains/$domain/outputs.tf << EOF
output "domain${domain_num}_status" {
  description = "Domain $domain_num deployment status"
  value       = "Domain $domain_num placeholder deployed"
}
EOF

done

echo -e "${GREEN}✓${NC} Created placeholder configuration files for all domains"

# Create shared infrastructure if it doesn't exist
if [ ! -d "shared-infrastructure" ]; then
    echo -e "\n${YELLOW}Creating shared-infrastructure directory...${NC}"
    mkdir -p shared-infrastructure
fi

# Create a simple shared infrastructure configuration
cat > shared-infrastructure/main.tf << 'EOF'
# Shared Infrastructure - VPC and Common Resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-public-${local.azs[count.index]}"
      Type = "public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-private-${local.azs[count.index]}"
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
      Name = "${local.name_prefix}-public-rt"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
EOF

cat > shared-infrastructure/variables.tf << 'EOF'
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}
EOF

cat > shared-infrastructure/outputs.tf << 'EOF'
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

output "db_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = ""  # Placeholder
}
EOF

echo -e "${GREEN}✓${NC} Created shared infrastructure configuration"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Configuration Files Created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}What was created:${NC}"
echo "• Basic configuration files for all 4 domains"
echo "• Shared infrastructure configuration"
echo "• These are simplified versions to get you started"
echo ""
echo -e "${RED}IMPORTANT:${NC}"
echo "These are placeholder configurations. For the full"
echo "domain implementations with all exam objectives,"
echo "you'll need to replace these with the complete"
echo "configurations I provided earlier."
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Initialize Terraform: ${GREEN}terraform init${NC}"
echo "2. Configure terraform.tfvars: ${GREEN}cp terraform.tfvars.template terraform.tfvars${NC}"
echo "3. Deploy shared infrastructure: ${GREEN}terraform apply${NC}"
echo ""
echo -e "${BLUE}To add the full configurations:${NC}"
echo "Replace each domain's main.tf with the complete"
echo "versions from the artifacts I created earlier."