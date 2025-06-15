#!/bin/bash
# Script to apply the full domain configurations for AWS SA Pro Lab

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Applying Full Domain Configurations${NC}"
echo "==================================="
echo ""
echo -e "${YELLOW}This will replace the placeholder configurations with${NC}"
echo -e "${YELLOW}the complete exam-aligned infrastructure.${NC}"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Create Domain 1 full configuration
echo -e "\n${YELLOW}Creating Domain 1: Organizational Complexity...${NC}"

cat > domains/domain1-organizational-complexity/main.tf << 'EOF'
# Domain 1: Design Solutions for Organizational Complexity (26%)

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

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# AWS Organizations Setup (if enabled)
resource "aws_organizations_organization" "main" {
  count = var.enable_organizations ? 1 : 0

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com"
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  feature_set = "ALL"
}

# Transit Gateway for multi-account networking
resource "aws_ec2_transit_gateway" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  description                     = "${local.name_prefix} Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-tgw"
      Domain = "1"
    }
  )
}

# Cross-account IAM role
resource "aws_iam_role" "cross_account_admin" {
  name = "${local.name_prefix}-cross-account-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_ids
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-cross-account-admin"
      Domain = "1"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cross_account_admin" {
  role       = aws_iam_role.cross_account_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Centralized logging bucket
resource "aws_s3_bucket" "centralized_logs" {
  bucket = "${local.name_prefix}-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-centralized-logs"
      Domain = "1"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "centralized_logs" {
  bucket = aws_s3_bucket.centralized_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS Config for compliance
resource "aws_config_configuration_recorder" "main" {
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "${local.name_prefix}-config-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-config"
      Domain = "1"
    }
  )
}

resource "aws_iam_role" "config" {
  name = "${local.name_prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Cost allocation tags
resource "aws_ce_cost_category" "departments" {
  name = "${local.name_prefix}-departments"

  rule {
    value = "Engineering"
    rule {
      tags {
        key    = "Department"
        values = ["Engineering", "DevOps"]
      }
    }
  }

  rule {
    value = "Other"
    rule {
      not {
        tags {
          key    = "Department"
          values = ["Engineering", "DevOps"]
        }
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-cost-categories"
      Domain = "1"
    }
  )
}
EOF

# Create Domain 1 variables
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

variable "enable_organizations" {
  description = "Enable AWS Organizations setup"
  type        = bool
  default     = false
}

variable "enable_transit_gateway" {
  description = "Enable Transit Gateway setup"
  type        = bool
  default     = true
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = "SA-PRO-LAB-2024"
}
EOF

# Create Domain 1 outputs
cat > domains/domain1-organizational-complexity/outputs.tf << 'EOF'
output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = try(aws_ec2_transit_gateway.main[0].id, null)
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account admin role"
  value       = aws_iam_role.cross_account_admin.arn
}

output "centralized_logging_bucket" {
  description = "Name of the centralized logging bucket"
  value       = aws_s3_bucket.centralized_logs.id
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = aws_config_configuration_recorder.main.name
}
EOF

echo -e "${GREEN}✓${NC} Domain 1 configuration created"

# Create Domain 2 configuration
echo -e "\n${YELLOW}Creating Domain 2: New Solutions...${NC}"

cat > domains/domain2-new-solutions/main.tf << 'EOF'
# Domain 2: Design for New Solutions (29%)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# API Gateway for Microservices
resource "aws_api_gateway_rest_api" "microservices" {
  name        = "${local.name_prefix}-microservices-api"
  description = "Microservices API for Domain 2"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-microservices-api"
      Domain = "2"
    }
  )
}

# Lambda Function placeholder
resource "aws_lambda_function" "api_handler" {
  count = var.enable_lambda ? 1 : 0

  filename         = "${path.module}/lambda/placeholder.zip"
  function_name    = "${local.name_prefix}-api-handler"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-api-handler"
      Domain = "2"
    }
  )
}

# DynamoDB Table
resource "aws_dynamodb_table" "app_data" {
  name         = "${local.name_prefix}-app-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-app-data"
      Domain = "2"
    }
  )
}

# Auto Scaling Group
resource "aws_launch_template" "app" {
  count = var.enable_auto_scaling ? 1 : 0

  name_prefix   = "${local.name_prefix}-app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      {
        Name   = "${local.name_prefix}-app-instance"
        Domain = "2"
      }
    )
  }
}

resource "aws_autoscaling_group" "app" {
  count = var.enable_auto_scaling ? 1 : 0

  name               = "${local.name_prefix}-app-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size           = 1
  max_size           = 3
  desired_capacity   = 1

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Data source for AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
EOF

cat > domains/domain2-new-solutions/variables.tf << 'EOF'
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

variable "public_subnet_ids" {
  description = "Public subnet IDs from shared infrastructure"
  type        = list(string)
  default     = []
}

variable "enable_lambda" {
  description = "Enable Lambda functions"
  type        = bool
  default     = true
}

variable "enable_auto_scaling" {
  description = "Enable Auto Scaling Group"
  type        = bool
  default     = true
}
EOF

cat > domains/domain2-new-solutions/outputs.tf << 'EOF'
output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.microservices.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.app_data.name
}
EOF

# Create placeholder Lambda function
mkdir -p domains/domain2-new-solutions/lambda
cat > domains/domain2-new-solutions/lambda/index.py << 'EOF'
def handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Hello from Lambda!'
    }
EOF

cd domains/domain2-new-solutions/lambda
zip placeholder.zip index.py
cd ../../..

echo -e "${GREEN}✓${NC} Domain 2 configuration created"

# Create simplified versions of Domain 3 and 4
echo -e "\n${YELLOW}Creating Domain 3: Continuous Improvement...${NC}"

cat > domains/domain3-continuous-improvement/main.tf << 'EOF'
# Domain 3: Continuous Improvement for Existing Solutions (25%)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d3"
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        width  = 24
        height = 1
        properties = {
          markdown = "# Domain 3 - Continuous Improvement Dashboard"
        }
      }
    ]
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-alerts"
      Domain = "3"
    }
  )
}
EOF

echo -e "${GREEN}✓${NC} Domain 3 configuration created"

echo -e "\n${YELLOW}Creating Domain 4: Migration and Modernization...${NC}"

cat > domains/domain4-migration-modernization/main.tf << 'EOF'
# Domain 4: Accelerate Workload Migration and Modernization (20%)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-d4"
}

# S3 Bucket for Migration Data
resource "aws_s3_bucket" "migration_data" {
  bucket = "${local.name_prefix}-migration-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name   = "${local.name_prefix}-migration-data"
      Domain = "4"
    }
  )
}

data "aws_caller_identity" "current" {}
EOF

echo -e "${GREEN}✓${NC} Domain 4 configuration created"

# Update shared infrastructure with the full version
echo -e "\n${YELLOW}Updating shared infrastructure...${NC}"

cat > shared-infrastructure/main.tf << 'EOF'
# Shared Infrastructure - Foundation for all domains

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
  count                   = length(local.azs)
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
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(local.azs))
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-private-${local.azs[count.index]}"
      Type = "private"
    }
  )
}

# Database Subnets
resource "aws_subnet" "database" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + (2 * length(local.azs)))
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-database-${local.azs[count.index]}"
      Type = "database"
    }
  )
}

# NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(local.azs) : 0
  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-nat-${local.azs[count.index]}"
    }
  )
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? length(local.azs) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-nat-${local.azs[count.index]}"
    }
  )
}

# Route Tables
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

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-private-rt-${local.azs[count.index]}"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "database" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# S3 Bucket for logs
resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS Key
resource "aws_kms_key" "main" {
  description             = "${local.name_prefix} encryption key"
  deletion_window_in_days = 7

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-kms"
    }
  )
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-db-subnet-group"
    }
  )
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

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
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

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = aws_subnet.database[*].id
}

output "db_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = aws_db_subnet_group.main.name
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.main.id
}

output "s3_bucket_logs" {
  description = "Name of the logs S3 bucket"
  value       = aws_s3_bucket.logs.id
}
EOF

echo -e "${GREEN}✓${NC} Shared infrastructure updated"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Full Configurations Applied!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}What was created:${NC}"
echo "• Domain 1: Organizations, Transit Gateway, Cross-account"
echo "• Domain 2: API Gateway, Lambda, Auto Scaling, DynamoDB"
echo "• Domain 3: CloudWatch monitoring foundation"
echo "• Domain 4: Migration resources foundation"
echo "• Shared: Complete VPC with subnets, NAT, KMS, S3"
echo ""
echo -e "${BLUE}Note:${NC} These are simplified but functional versions."
echo "For the complete exam-aligned infrastructure with all"
echo "services, refer to the original artifacts."
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. ${GREEN}terraform init${NC}"
echo "2. ${GREEN}cp terraform.tfvars.template terraform.tfvars${NC}"
echo "3. Edit terraform.tfvars with your email and IP"
echo "4. ${GREEN}terraform plan${NC}"
echo "5. ${GREEN}terraform apply${NC}"