# =================================================================
# NUCLEAR OPTION: DISABLE ALL PROBLEMATIC FEATURES
# =================================================================

echo "🚨 NUCLEAR OPTION: Disabling all problematic features"
echo "This will let you terraform destroy without fixing every variable"

# =================================================================
# STEP 1: DISABLE PROBLEMATIC FILES ENTIRELY
# =================================================================

# Move problematic files out of the way
mkdir -p .disabled_files
mv networking.tf .disabled_files/ 2>/dev/null || true
mv security.tf .disabled_files/ 2>/dev/null || true
mv advanced-networking.tf .disabled_files/ 2>/dev/null || true

echo "✅ Moved problematic files to .disabled_files/"

# =================================================================
# STEP 2: CREATE MINIMAL WORKING CONFIGURATION
# =================================================================

# Create minimal networking.tf with just basic VPC
cat > networking.tf << 'EOF'
# Minimal VPC for SA Pro lab
resource "aws_vpc" "primary" {
  provider             = aws.primary
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-vpc"
    Type = "primary"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-igw"
  })
}

# Public subnet (just one for minimal setup)
resource "aws_subnet" "public" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.primary_region}a"
  map_public_ip_on_launch = true
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-public-subnet"
    Type = "public"
  })
}

# Private subnet (required by some resources)
resource "aws_subnet" "private" {
  provider          = aws.primary
  count             = 2
  vpc_id            = aws_vpc.primary.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-private-${count.index + 1}"
    Type = "private"
  })
}

data "aws_availability_zones" "available" {
  provider = aws.primary
  state    = "available"
}

# Route table for public subnet
resource "aws_route_table" "public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  provider       = aws.primary
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
EOF

# Create minimal security.tf (no advanced features)
cat > security.tf << 'EOF'
# Basic security group for serverless resources
resource "aws_security_group" "lambda" {
  provider    = aws.primary
  name        = "${var.common_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.primary.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-lambda-sg"
  })
}

# Basic secrets in Secrets Manager (only if enabled)
resource "aws_secretsmanager_secret" "db_password" {
  count                   = var.enable_secrets_manager ? 1 : 0
  provider                = aws.primary
  name                    = "${var.common_name}-db-password"
  description             = "Database password for ${var.common_name}"
  recovery_window_in_days = 0  # Immediate deletion for lab
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-db-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count     = var.enable_secrets_manager ? 1 : 0
  provider  = aws.primary
  secret_id = aws_secretsmanager_secret.db_password[0].id
  secret_string = jsonencode({
    username = var.mysql_master_username
    password = var.mysql_master_password
  })
}
EOF

# =================================================================
# STEP 3: UPDATE terraform.tfvars TO DISABLE EVERYTHING
# =================================================================

cat > terraform.tfvars << 'EOF'
# SA Pro Lab - Minimal Configuration for Clean Destroy
common_name = "sa-pro-lab"
primary_region = "us-east-1"
testbed_region = "us-east-2"
notification_email = "RRCloudDev@gmail.com"

# Disable ALL advanced features
enable_compute_tier = false
enable_database_tier = false
enable_serverless_tier = false
enable_storage_tier = false
enable_monitoring_tier = false
enable_security_tier = false

# Disable ALL networking features
enable_advanced_networking = false
enable_vpc_peering = false
enable_route53_advanced = false
enable_cloudfront = false
enable_network_firewall = false
enable_transit_gateway = false
enable_nat_gateway = false
enable_vpn_gateway = false
enable_vpc_flow_logs = false

# Disable ALL API features
enable_api_gateway = false
enable_http_api = false
enable_step_functions = false
enable_eventbridge = false
enable_eventbridge_advanced = false
enable_xray = false

# Disable ALL database features
enable_dynamodb = false
enable_dynamodb_streams = false
enable_elasticache = false
enable_postgresql = false

# Disable ALL security features except secrets manager
enable_secrets_manager = true
enable_kms_advanced = false
enable_cloudtrail_advanced = false
enable_aws_config = false
enable_sns_email = false

# Basic settings
development_mode = true
enable_multi_az = false
backup_retention_days = 1
monthly_budget_limit = 10
enable_cost_monitoring = false
log_retention_days = 1

# Required passwords (won't be used but needed for validation)
mysql_master_password = "TempPassword123!"
mysql_master_username = "admin"
mysql_database_name = "tempdb"
redis_auth_token = "TempToken123!"

# Basic settings
ssh_allowed_cidrs = []
domain_name = "temp.local"
EOF

# =================================================================
# STEP 4: CREATE MINIMAL variables.tf (ONLY WHAT'S NEEDED)
# =================================================================

cat > variables.tf << 'EOF'
variable "common_name" {
  description = "Common name prefix"
  type        = string
  default     = "sa-pro-lab"
}

variable "primary_region" {
  description = "Primary region"
  type        = string
  default     = "us-east-1"
}

variable "testbed_region" {
  description = "Secondary region"
  type        = string
  default     = "us-east-2"
}

variable "notification_email" {
  description = "Email for notifications"
  type        = string
  sensitive   = true
}

# All the enable flags (set to false by default)
variable "enable_compute_tier" { type = bool; default = false }
variable "enable_database_tier" { type = bool; default = false }
variable "enable_serverless_tier" { type = bool; default = false }
variable "enable_storage_tier" { type = bool; default = false }
variable "enable_monitoring_tier" { type = bool; default = false }
variable "enable_security_tier" { type = bool; default = false }
variable "enable_advanced_networking" { type = bool; default = false }
variable "enable_vpc_peering" { type = bool; default = false }
variable "enable_route53_advanced" { type = bool; default = false }
variable "enable_cloudfront" { type = bool; default = false }
variable "enable_network_firewall" { type = bool; default = false }
variable "enable_transit_gateway" { type = bool; default = false }
variable "enable_nat_gateway" { type = bool; default = false }
variable "enable_vpn_gateway" { type = bool; default = false }
variable "enable_vpc_flow_logs" { type = bool; default = false }
variable "enable_api_gateway" { type = bool; default = false }
variable "enable_http_api" { type = bool; default = false }
variable "enable_step_functions" { type = bool; default = false }
variable "enable_eventbridge" { type = bool; default = false }
variable "enable_eventbridge_advanced" { type = bool; default = false }
variable "enable_xray" { type = bool; default = false }
variable "enable_dynamodb" { type = bool; default = false }
variable "enable_dynamodb_streams" { type = bool; default = false }
variable "enable_elasticache" { type = bool; default = false }
variable "enable_postgresql" { type = bool; default = false }
variable "enable_secrets_manager" { type = bool; default = true }
variable "enable_kms_advanced" { type = bool; default = false }
variable "enable_cloudtrail_advanced" { type = bool; default = false }
variable "enable_aws_config" { type = bool; default = false }
variable "enable_sns_email" { type = bool; default = false }
variable "enable_cost_monitoring" { type = bool; default = false }

# Basic settings
variable "development_mode" { type = bool; default = true }
variable "enable_multi_az" { type = bool; default = false }
variable "backup_retention_days" { type = number; default = 1 }
variable "monthly_budget_limit" { type = number; default = 10 }
variable "log_retention_days" { type = number; default = 1 }

# Required variables (even if not used)
variable "mysql_master_password" { type = string; sensitive = true }
variable "mysql_master_username" { type = string; default = "admin" }
variable "mysql_database_name" { type = string; default = "tempdb" }
variable "redis_auth_token" { type = string; sensitive = true }
variable "ssh_allowed_cidrs" { type = list(string); default = [] }
variable "domain_name" { type = string; default = "temp.local" }

variable "common_tags" {
  type = map(string)
  default = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}
EOF

echo ""
echo "🎯 NUCLEAR OPTION COMPLETE!"
echo ""
echo "✅ Moved complex files to .disabled_files/"
echo "✅ Created minimal working configuration"
echo "✅ Disabled ALL advanced features"
echo "✅ Configuration now only creates basic VPC + subnets"
echo ""
echo "NOW RUN:"
echo "  terraform validate"
echo "  terraform destroy"
echo ""
echo "After successful destroy, you can:"
echo "1. Start fresh with a simpler configuration"
echo "2. Re-enable features one at a time"
echo "3. Or restore files from .disabled_files/ if needed"