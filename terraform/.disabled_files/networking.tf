# networking.tf - Complete VPC and Networking Infrastructure
# Multi-region setup: us-east-1 (primary), us-east-2 (testbed), us-west-1 (networking)

# Local values for consistent networking

# ================================================================
# PRIMARY REGION VPC (us-east-1) - Main SysOps lab environment
# ================================================================




resource "aws_vpc" "primary" {
  provider             = aws.primary
  cidr_block           = local.vpc_cidrs.primary
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name   = "${local.common_name}-primary-vpc"
    Type   = "primary-sysops-lab"
    Region = "us-east-1"  # Updated
  }
}

# Internet Gateway for primary VPC
resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  
  tags = {
    Name = "${local.common_name}-primary-igw"
  }
}

# Public subnets in primary region (multi-AZ for HA)
resource "aws_subnet" "primary_public" {
  provider = aws.primary
  count    = length(local.azs.primary)
  
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = cidrsubnet(local.vpc_cidrs.primary, 8, count.index)
  availability_zone       = local.azs.primary[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.common_name}-primary-public-${substr(local.azs.primary[count.index], -1, 1)}"
    Type = "public"
    Tier = "web"
  }
}

# Private subnets in primary region
resource "aws_subnet" "primary_private" {
  provider = aws.primary
  count    = length(local.azs.primary)
  
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(local.vpc_cidrs.primary, 8, count.index + 10)
  availability_zone = local.azs.primary[count.index]
  
  tags = {
    Name = "${local.common_name}-primary-private-${substr(local.azs.primary[count.index], -1, 1)}"
    Type = "private"
    Tier = "application"
  }
}
resource "aws_subnet" "private" {
  provider = aws.primary
  count    = length(local.azs.primary)
  
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(local.vpc_cidrs.primary, 8, count.index + 10)
  availability_zone = local.azs.primary[count.index]
  
  tags = {
    Name = "${local.common_name}-private-${substr(local.azs.primary[count.index], -1, 1)}"
    Type = "private"
    Tier = "application"
  }
}

# Database subnets in primary region
resource "aws_subnet" "primary_database" {
  provider = aws.primary
  count    = length(local.azs.primary)
  
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(local.vpc_cidrs.primary, 8, count.index + 20)
  availability_zone = local.azs.primary[count.index]
  
  tags = {
    Name = "${local.common_name}-primary-db-${substr(local.azs.primary[count.index], -1, 1)}"
    Type = "database"
    Tier = "data"
  }
}

# NAT Gateways for private subnet internet access
resource "aws_eip" "primary_nat" {
  provider = aws.primary
  count    = var.enable_nat_gateway ? length(local.azs.primary) : 0
  domain   = "vpc"
  
  depends_on = [aws_internet_gateway.primary]
  
  tags = {
    Name = "${local.common_name}-primary-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "primary" {
  provider      = aws.primary
  count         = var.enable_nat_gateway ? length(local.azs.primary) : 0
  allocation_id = aws_eip.primary_nat[count.index].id
  subnet_id     = aws_subnet.primary_public[count.index].id
  
  tags = {
    Name = "${local.common_name}-primary-nat-${count.index + 1}"
  }
}

# Route tables for primary VPC
resource "aws_route_table" "primary_public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }
  
  tags = {
    Name = "${local.common_name}-primary-public-rt"
  }
}

resource "aws_route_table" "primary_private" {
  provider = aws.primary
  count    = length(local.azs.primary)
  vpc_id   = aws_vpc.primary.id
  
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.primary[count.index].id
    }
  }
  
  tags = {
    Name = "${local.common_name}-primary-private-rt-${count.index + 1}"
  }
}

# Route table associations
resource "aws_route_table_association" "primary_public" {
  provider       = aws.primary
  count          = length(aws_subnet.primary_public)
  subnet_id      = aws_subnet.primary_public[count.index].id
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table_association" "primary_private" {
  provider       = aws.primary
  count          = length(aws_subnet.primary_private)
  subnet_id      = aws_subnet.primary_private[count.index].id
  route_table_id = aws_route_table.primary_private[count.index].id
}

resource "aws_route_table_association" "primary_database" {
  provider       = aws.primary
  count          = length(aws_subnet.primary_database)
  subnet_id      = aws_subnet.primary_database[count.index].id
  route_table_id = aws_route_table.primary_private[count.index].id
}

# ================================================================
# TESTBED REGION VPC (us-east-2) - DR and testing environment
# ================================================================

resource "aws_vpc" "testbed" {
  provider             = aws.testbed
  cidr_block           = local.vpc_cidrs.testbed
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name   = "${local.common_name}-testbed-vpc"
    Type   = "disaster-recovery-testing"
    Region = "us-east-2"  # Updated
  }
}

resource "aws_internet_gateway" "testbed" {
  provider = aws.testbed
  vpc_id   = aws_vpc.testbed.id
  
  tags = {
    Name = "${local.common_name}-testbed-igw"
  }
}

# Simplified testbed subnets (public/private only)
resource "aws_subnet" "testbed_public" {
  provider = aws.testbed
  count    = length(local.azs.testbed)
  
  vpc_id                  = aws_vpc.testbed.id
  cidr_block              = cidrsubnet(local.vpc_cidrs.testbed, 8, count.index)
  availability_zone       = local.azs.testbed[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${local.common_name}-testbed-public-${substr(local.azs.testbed[count.index], -1, 1)}"
    Type = "public"
  }
}

resource "aws_subnet" "testbed_private" {
  provider = aws.testbed
  count    = length(local.azs.testbed)
  
  vpc_id            = aws_vpc.testbed.id
  cidr_block        = cidrsubnet(local.vpc_cidrs.testbed, 8, count.index + 10)
  availability_zone = local.azs.testbed[count.index]
  
  tags = {
    Name = "${local.common_name}-testbed-private-${substr(local.azs.testbed[count.index], -1, 1)}"
    Type = "private"
  }
}

# ================================================================
# NETWORKING REGION VPC (us-west-1) - Advanced networking scenarios
# ================================================================

resource "aws_vpc" "networking" {
  provider             = aws.networking
  cidr_block           = local.vpc_cidrs.networking
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name   = "${local.common_name}-networking-vpc"
    Type   = "advanced-networking-lab"
    Region = "us-west-1"  # Keep as us-west-1
  }
}

resource "aws_internet_gateway" "networking" {
  provider = aws.networking
  vpc_id   = aws_vpc.networking.id
  
  tags = {
    Name = "${local.common_name}-networking-igw"
  }
}

# VPC Peering between regions for advanced networking scenarios
resource "aws_vpc_peering_connection" "primary_to_testbed" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.testbed.id
  peer_region = "us-east-2"  # Updated
  auto_accept = false
  
  tags = {
    Name = "${local.common_name}-primary-to-testbed-peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "primary_to_testbed" {
  provider                  = aws.testbed
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_testbed.id
  auto_accept               = true
  
  tags = {
    Name = "${local.common_name}-primary-to-testbed-peering-accepter"
  }
}

# VPC Peering between primary and networking regions
resource "aws_vpc_peering_connection" "primary_to_networking" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.networking.id
  peer_region = "us-west-1"  # Keep as us-west-1
  auto_accept = false
  
  tags = {
    Name = "${local.common_name}-primary-to-networking-peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "primary_to_networking" {
  provider                  = aws.networking
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_networking.id
  auto_accept               = true
  
  tags = {
    Name = "${local.common_name}-primary-to-networking-peering-accepter"
  }
}

# VPC Peering between primary and secondary (testbed) regions
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  count         = var.enable_advanced_networking && var.enable_vpc_peering ? 1 : 0
  provider      = aws.primary
  vpc_id        = aws_vpc.primary.id
  peer_vpc_id   = aws_vpc.secondary[0].id
  peer_region   = "us-east-2"  # Updated to match testbed region
  auto_accept   = false

  tags = {
    Name        = "${local.common_name}-peering"
    Type        = "vpc-peering"
    Environment = var.common_tags.Environment
  }
}

# VPC Flow Logs for monitoring and security analysis
resource "aws_flow_log" "primary_vpc" {
  provider        = aws.primary
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.primary.id
  
  tags = {
    Name = "${local.common_name}-primary-vpc-flow-log"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  provider          = aws.primary
  name              = "/aws/vpc/flowlogs/${local.common_name}"
  retention_in_days = 7
  
  tags = {
    Name = "${local.common_name}-vpc-flow-logs"
  }
}

resource "aws_iam_role" "flow_log" {
  provider = aws.primary
  name     = "${local.common_name}-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  provider = aws.primary
  name     = "${local.common_name}-flow-log-policy"
  role     = aws_iam_role.flow_log.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Security Groups for different tiers
resource "aws_security_group" "web_tier" {
  provider    = aws.primary
  name        = "${local.common_name}-web-tier"
  description = "Security group for web tier"
  vpc_id      = aws_vpc.primary.id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidrs.primary]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.common_name}-web-tier-sg"
    Tier = "web"
  }
}

resource "aws_security_group" "app_tier" {
  provider    = aws.primary
  name        = "${local.common_name}-app-tier"
  description = "Security group for application tier"
  vpc_id      = aws_vpc.primary.id
  
  ingress {
    description     = "From web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier.id]
  }
  
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidrs.primary]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.common_name}-app-tier-sg"
    Tier = "application"
  }
}

resource "aws_security_group" "db_tier" {
  provider    = aws.primary
  name        = "${local.common_name}-db-tier"
  description = "Security group for database tier"
  vpc_id      = aws_vpc.primary.id
  
  ingress {
    description     = "MySQL/Aurora from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }
  
  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.common_name}-db-tier-sg"
    Tier = "database"
  }
}

# Additional VPC Endpoints for private connectivity
resource "aws_vpc_endpoint" "s3" {
  provider        = aws.primary
  vpc_id          = aws_vpc.primary.id
  service_name    = "com.amazonaws.us-east-1.s3"      # Updated
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.primary_private[*].id
  
  tags = {
    Name = "${local.common_name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  provider        = aws.primary
  vpc_id          = aws_vpc.primary.id
  service_name    = "com.amazonaws.us-east-1.dynamodb"  # Updated
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.primary_private[*].id
  
  tags = {
    Name = "${local.common_name}-dynamodb-endpoint"
  }
}

resource "aws_route53_health_check" "alb" {
  count                           = var.enable_advanced_networking && var.enable_route53_advanced && var.enable_compute_tier ? 1 : 0
  provider                        = aws.primary
  fqdn                            = aws_lb.web_alb[0].dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = "us-east-1"  # Updated
  cloudwatch_alarm_name           = "${local.common_name}-alb-health"
  insufficient_data_health_status = "Unhealthy"

  tags = {
    Name        = "${local.common_name}-alb-health-check"
    Type        = "health-check"
    Environment = var.common_tags.Environment
  }
}

# Outputs for networking information
output "vpc_ids" {
  description = "VPC IDs for all regions"
  value = {
    primary    = aws_vpc.primary.id
    testbed    = aws_vpc.testbed.id
    networking = aws_vpc.networking.id
  }
}

output "subnet_ids" {
  description = "Subnet IDs by type and region"
  value = {
    primary_public   = aws_subnet.primary_public[*].id
    primary_private  = aws_subnet.primary_private[*].id
    primary_database = aws_subnet.primary_database[*].id
    testbed_public   = aws_subnet.testbed_public[*].id
    testbed_private  = aws_subnet.testbed_private[*].id
  }
}

output "security_group_ids" {
  description = "Security group IDs by tier"
  value = {
    web = aws_security_group.web_tier.id
    app = aws_security_group.app_tier.id
    db  = aws_security_group.db_tier.id
  }
}

output "peering_connection_ids" {
  description = "VPC peering connection IDs"
  value = {
    primary_to_testbed    = aws_vpc_peering_connection.primary_to_testbed.id
    primary_to_networking = aws_vpc_peering_connection.primary_to_networking.id
  }
}
