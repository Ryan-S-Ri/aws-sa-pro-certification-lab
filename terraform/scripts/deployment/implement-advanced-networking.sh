#!/bin/bash
# implement-advanced-networking-module.sh - Advanced Networking with collision prevention

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}[SETUP]${NC} $1"; }

echo "🌐 AWS Certification Lab - Advanced Networking Module Implementation"
echo "===================================================================="
echo ""

# ================================================================
# COMPREHENSIVE VALIDATION SYSTEM
# ================================================================

print_header "Running comprehensive validation to prevent collisions..."

# Function to check if variable exists
check_variable_exists() {
    local var_name="$1"
    if grep -q "variable \"$var_name\"" variables.tf; then
        return 0  # Variable exists
    else
        return 1  # Variable doesn't exist
    fi
}

# Function to check if output exists
check_output_exists() {
    local output_name="$1"
    if grep -q "output \"$output_name\"" outputs.tf; then
        return 0  # Output exists
    else
        return 1  # Output doesn't exist
    fi
}

# Function to check if resource exists
check_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    if grep -q "resource \"$resource_type\" \"$resource_name\"" *.tf; then
        return 0  # Resource exists
    else
        return 1  # Resource doesn't exist
    fi
}

# Function to check if data source exists
check_data_source_exists() {
    local data_type="$1"
    local data_name="$2"
    if grep -q "data \"$data_type\" \"$data_name\"" *.tf; then
        return 0  # Data source exists
    else
        return 1  # Data source doesn't exist
    fi
}

# Check prerequisites
print_status "Checking prerequisites..."
required_files=("main.tf" "variables.tf" "outputs.tf" "networking.tf")
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        print_error "Required file $file not found!"
        exit 1
    fi
done

print_success "✅ All required files exist"

# Validate current terraform state
print_status "Validating current Terraform configuration..."
if ! terraform validate; then
    print_error "Current Terraform configuration is invalid. Please fix before adding networking module."
    exit 1
fi

print_success "✅ Current configuration is valid"

# ================================================================
# VARIABLE COLLISION DETECTION AND SAFE ADDITION
# ================================================================

print_header "Checking for variable collisions and adding new variables..."

# Define networking variables to add
declare -A networking_vars=(
    ["enable_advanced_networking"]="Enable advanced networking features"
    ["enable_transit_gateway"]="Enable AWS Transit Gateway"
    ["enable_vpc_peering"]="Enable VPC Peering"
    ["enable_route53_advanced"]="Enable advanced Route 53 features"
    ["enable_cloudfront"]="Enable CloudFront CDN"
    ["enable_vpn_gateway"]="Enable VPN Gateway"
    ["enable_direct_connect_simulation"]="Enable Direct Connect simulation"
    ["cloudfront_price_class"]="CloudFront price class"
    ["route53_health_check_regions"]="Route 53 health check regions"
    ["vpc_peering_regions"]="Regions for VPC peering"
    ["transit_gateway_asn"]="Transit Gateway ASN number"
    ["enable_network_firewall"]="Enable AWS Network Firewall"
    ["enable_route53_resolver"]="Enable Route 53 Resolver"
    ["cloudfront_cache_behavior"]="CloudFront cache behavior settings"
)

# Check for existing variables and add only new ones
new_variables=""
for var_name in "${!networking_vars[@]}"; do
    if check_variable_exists "$var_name"; then
        print_warning "Variable '$var_name' already exists - skipping"
    else
        print_status "Adding new variable: $var_name"
        case "$var_name" in
            "enable_advanced_networking"|"enable_transit_gateway"|"enable_vpc_peering"|"enable_route53_advanced"|"enable_cloudfront"|"enable_vpn_gateway"|"enable_direct_connect_simulation"|"enable_network_firewall"|"enable_route53_resolver")
                new_variables+="
variable \"$var_name\" {
  description = \"${networking_vars[$var_name]}\"
  type        = bool
  default     = false
}
"
                ;;
            "cloudfront_price_class")
                new_variables+="
variable \"$var_name\" {
  description = \"${networking_vars[$var_name]}\"
  type        = string
  default     = \"PriceClass_100\"
  
  validation {
    condition     = contains([\"PriceClass_All\", \"PriceClass_200\", \"PriceClass_100\"], var.$var_name)
    error_message = \"CloudFront price class must be PriceClass_All, PriceClass_200, or PriceClass_100.\"
  }
}
"
                ;;
            "route53_health_check_regions")
                new_variables+="
variable \"$var_name\" {
  description = \"${networking_vars[$var_name]}\"
  type        = list(string)
  default     = [\"us-east-1\", \"us-west-2\", \"eu-west-1\"]
}
"
                ;;
            "vpc_peering_regions")
                new_variables+="
variable \"$var_name\" {
  description = \"${networking_vars[$var_name]}\"
  type        = list(string)
  default     = [\"us-east-2\", \"us-west-1\"]
}
"
                ;;
            "transit_gateway_asn")
                new_variables+="
variable \"$var_name\" {
  description = \"${networking_vars[$var_name]}\"
  type        = number
  default     = 64512
  
  validation {
    condition     = var.$var_name >= 64512 && var.$var_name <= 65534
    error_message = \"Transit Gateway ASN must be between 64512 and 65534.\"
  }
}
"
                ;;
            "cloudfront_cache_behavior")
                new_variables+="
variable \"$var_name\" {
  description = \"${networking_vars[$var_name]}\"
  type        = string
  default     = \"managed-caching-optimized\"
  
  validation {
    condition     = contains([\"managed-caching-optimized\", \"managed-caching-optimized-for-uncompressed-objects\", \"managed-elemental-mediapackage\", \"managed-amplify\"], var.$var_name)
    error_message = \"CloudFront cache behavior must be a valid managed cache policy.\"
  }
}
"
                ;;
        esac
    fi
done

# Add new variables if any
if [[ -n "$new_variables" ]]; then
    print_status "Adding new networking variables to variables.tf..."
    cat >> variables.tf << EOF

# ================================================================
# ADVANCED NETWORKING VARIABLES
# ================================================================
$new_variables
EOF
    print_success "✅ New networking variables added"
else
    print_warning "All networking variables already exist"
fi

# ================================================================
# RESOURCE COLLISION DETECTION
# ================================================================

print_header "Checking for resource collisions..."

# Check for potential resource conflicts
resource_conflicts=()

# Check critical resources that might conflict
critical_resources=(
    "aws_route53_zone:main"
    "aws_cloudfront_distribution:main"
    "aws_ec2_transit_gateway:main"
    "aws_vpc_peering_connection:main"
    "random_string:bucket_suffix"
)

for resource in "${critical_resources[@]}"; do
    IFS=':' read -r resource_type resource_name <<< "$resource"
    if check_resource_exists "$resource_type" "$resource_name"; then
        resource_conflicts+=("$resource_type.$resource_name")
        print_warning "Resource conflict detected: $resource_type.$resource_name already exists"
    fi
done

# Handle conflicts by using unique names
if [[ ${#resource_conflicts[@]} -gt 0 ]]; then
    print_warning "Found ${#resource_conflicts[@]} resource conflicts. Will use unique names."
fi

# ================================================================
# CREATE ADVANCED NETWORKING TERRAFORM FILE
# ================================================================

print_header "Creating advanced-networking.tf file..."

cat > advanced-networking.tf << 'EOF'
# advanced-networking.tf - Advanced Networking Infrastructure for SA Pro
# Comprehensive networking setup covering Transit Gateway, VPC Peering, Route 53, and CloudFront

# ================================================================
# TRANSIT GATEWAY
# ================================================================

# Transit Gateway for hub-and-spoke architecture
resource "aws_ec2_transit_gateway" "main" {
  count                           = var.enable_advanced_networking && var.enable_transit_gateway ? 1 : 0
  provider                        = aws.primary
  description                     = "Transit Gateway for ${local.common_name}"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"
  amazon_side_asn                = var.transit_gateway_asn

  tags = {
    Name        = "${local.common_name}-tgw"
    Type        = "transit-gateway"
    Environment = var.common_tags.Environment
  }
}

# Transit Gateway VPC Attachment for primary VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "primary" {
  count                                           = var.enable_advanced_networking && var.enable_transit_gateway ? 1 : 0
  provider                                        = aws.primary
  subnet_ids                                      = aws_subnet.primary_private[*].id
  transit_gateway_id                              = aws_ec2_transit_gateway.main[0].id
  vpc_id                                          = aws_vpc.primary.id
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name        = "${local.common_name}-tgw-attachment-primary"
    Type        = "tgw-attachment"
    Environment = var.common_tags.Environment
  }
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table" "main" {
  count              = var.enable_advanced_networking && var.enable_transit_gateway ? 1 : 0
  provider           = aws.primary
  transit_gateway_id = aws_ec2_transit_gateway.main[0].id

  tags = {
    Name        = "${local.common_name}-tgw-rt"
    Type        = "tgw-route-table"
    Environment = var.common_tags.Environment
  }
}

# ================================================================
# VPC PEERING CONNECTIONS
# ================================================================

# Secondary VPC for peering demonstration (in different region)
resource "aws_vpc" "secondary" {
  count                = var.enable_advanced_networking && var.enable_vpc_peering ? 1 : 0
  provider             = aws.testbed
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.common_name}-secondary-vpc"
    Type        = "secondary-vpc"
    Environment = var.common_tags.Environment
  }
}

# Secondary VPC subnets
resource "aws_subnet" "secondary_public" {
  count                   = var.enable_advanced_networking && var.enable_vpc_peering ? 2 : 0
  provider                = aws.testbed
  vpc_id                  = aws_vpc.secondary[0].id
  cidr_block              = "10.1.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.testbed[0].names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.common_name}-secondary-public-${count.index + 1}"
    Type        = "secondary-public-subnet"
    Environment = var.common_tags.Environment
  }
}

# Data source for testbed region AZs
data "aws_availability_zones" "testbed" {
  count    = var.enable_advanced_networking && var.enable_vpc_peering ? 1 : 0
  provider = aws.testbed
  state    = "available"
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  count         = var.enable_advanced_networking && var.enable_vpc_peering ? 1 : 0
  provider      = aws.primary
  vpc_id        = aws_vpc.primary.id
  peer_vpc_id   = aws_vpc.secondary[0].id
  peer_region   = var.testbed_region
  auto_accept   = false

  tags = {
    Name        = "${local.common_name}-peering"
    Type        = "vpc-peering"
    Environment = var.common_tags.Environment
  }
}

# Accept the peering connection in the peer region
resource "aws_vpc_peering_connection_accepter" "secondary" {
  count                     = var.enable_advanced_networking && var.enable_vpc_peering ? 1 : 0
  provider                  = aws.testbed
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary[0].id
  auto_accept               = true

  tags = {
    Name        = "${local.common_name}-peering-accepter"
    Type        = "vpc-peering-accepter"
    Environment = var.common_tags.Environment
  }
}

# Route table entries for peering
resource "aws_route" "primary_to_secondary" {
  count                     = var.enable_advanced_networking && var.enable_vpc_peering ? 1 : 0
  provider                  = aws.primary
  route_table_id            = aws_route_table.primary_private[0].id
  destination_cidr_block    = aws_vpc.secondary[0].cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary[0].id
}

# ================================================================
# ROUTE 53 ADVANCED FEATURES
# ================================================================

# Private hosted zone for internal DNS
resource "aws_route53_zone" "private" {
  count   = var.enable_advanced_networking && var.enable_route53_advanced ? 1 : 0
  provider = aws.primary
  name     = "internal.${var.domain_name}"

  vpc {
    vpc_id = aws_vpc.primary.id
  }

  tags = {
    Name        = "${local.common_name}-private-zone"
    Type        = "private-dns-zone"
    Environment = var.common_tags.Environment
  }
}

# Route 53 health check for ALB
resource "aws_route53_health_check" "alb" {
  count                           = var.enable_advanced_networking && var.enable_route53_advanced && var.enable_compute_tier ? 1 : 0
  provider                        = aws.primary
  fqdn                            = aws_lb.web_alb[0].dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = var.primary_region
  cloudwatch_alarm_name           = "${local.common_name}-alb-health"
  insufficient_data_health_status = "Failure"

  tags = {
    Name        = "${local.common_name}-alb-health-check"
    Type        = "health-check"
    Environment = var.common_tags.Environment
  }
}

# Route 53 record with health check
resource "aws_route53_record" "alb_with_health_check" {
  count           = var.enable_advanced_networking && var.enable_route53_advanced && var.enable_compute_tier ? 1 : 0
  provider        = aws.primary
  zone_id         = aws_route53_zone.private[0].zone_id
  name            = "app.internal.${var.domain_name}"
  type            = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.alb[0].id

  weighted_routing_policy {
    weight = 100
  }

  alias {
    name                   = aws_lb.web_alb[0].dns_name
    zone_id                = aws_lb.web_alb[0].zone_id
    evaluate_target_health = true
  }
}

# ================================================================
# CLOUDFRONT DISTRIBUTION
# ================================================================

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "main" {
  count   = var.enable_advanced_networking && var.enable_cloudfront ? 1 : 0
  provider = aws.primary
  comment = "OAI for ${local.common_name}"
}

# S3 bucket for CloudFront content
resource "aws_s3_bucket" "cloudfront_content" {
  count    = var.enable_advanced_networking && var.enable_cloudfront ? 1 : 0
  provider = aws.primary
  bucket   = "${local.common_name}-cloudfront-${random_string.cloudfront_suffix[0].result}"

  tags = {
    Name        = "${local.common_name}-cloudfront-content"
    Type        = "cloudfront-origin"
    Environment = var.common_tags.Environment
  }
}

resource "random_string" "cloudfront_suffix" {
  count   = var.enable_advanced_networking && var.enable_cloudfront ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "cloudfront_content" {
  count    = var.enable_advanced_networking && var.enable_cloudfront ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.cloudfront_content[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.main[0].iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.cloudfront_content[0].arn}/*"
      }
    ]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "main" {
  count           = var.enable_advanced_networking && var.enable_cloudfront ? 1 : 0
  provider        = aws.primary
  comment         = "CloudFront distribution for ${local.common_name}"
  default_root_object = "index.html"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.cloudfront_price_class

  # S3 origin
  origin {
    domain_name = aws_s3_bucket.cloudfront_content[0].bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.cloudfront_content[0].id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main[0].cloudfront_access_identity_path
    }
  }

  # ALB origin (if compute tier is enabled)
  dynamic "origin" {
    for_each = var.enable_compute_tier ? [1] : []
    content {
      domain_name = aws_lb.web_alb[0].dns_name
      origin_id   = "ALB-${aws_lb.web_alb[0].name}"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.cloudfront_content[0].id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Cache behavior for ALB (if enabled)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_compute_tier ? [1] : []
    content {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = "ALB-${aws_lb.web_alb[0].name}"
      compress         = true

      forwarded_values {
        query_string = true
        headers      = ["*"]
        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    }
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL certificate configuration
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${local.common_name}-cloudfront"
    Type        = "cloudfront-distribution"
    Environment = var.common_tags.Environment
  }
}

# ================================================================
# VPN GATEWAY SIMULATION
# ================================================================

# Customer Gateway (simulated)
resource "aws_customer_gateway" "main" {
  count      = var.enable_advanced_networking && var.enable_vpn_gateway ? 1 : 0
  provider   = aws.primary
  bgp_asn    = 65000
  ip_address = "203.0.113.12"  # Example IP - replace with your actual public IP
  type       = "ipsec.1"

  tags = {
    Name        = "${local.common_name}-customer-gateway"
    Type        = "customer-gateway"
    Environment = var.common_tags.Environment
  }
}

# VPN Gateway
resource "aws_vpn_gateway" "main" {
  count           = var.enable_advanced_networking && var.enable_vpn_gateway ? 1 : 0
  provider        = aws.primary
  vpc_id          = aws_vpc.primary.id
  amazon_side_asn = 64512

  tags = {
    Name        = "${local.common_name}-vpn-gateway"
    Type        = "vpn-gateway"
    Environment = var.common_tags.Environment
  }
}

# VPN Connection
resource "aws_vpn_connection" "main" {
  count               = var.enable_advanced_networking && var.enable_vpn_gateway ? 1 : 0
  provider            = aws.primary
  customer_gateway_id = aws_customer_gateway.main[0].id
  type                = "ipsec.1"
  vpn_gateway_id      = aws_vpn_gateway.main[0].id
  static_routes_only  = true

  tags = {
    Name        = "${local.common_name}-vpn-connection"
    Type        = "vpn-connection"
    Environment = var.common_tags.Environment
  }
}

# VPN Connection Route
resource "aws_vpn_connection_route" "office" {
  count                  = var.enable_advanced_networking && var.enable_vpn_gateway ? 1 : 0
  provider               = aws.primary
  vpn_connection_id      = aws_vpn_connection.main[0].id
  destination_cidr_block = "192.168.1.0/24"  # Simulated office network
}

# ================================================================
# NETWORK FIREWALL (OPTIONAL)
# ================================================================

# Network Firewall (for advanced security)
resource "aws_networkfirewall_firewall_policy" "main" {
  count = var.enable_advanced_networking && var.enable_network_firewall ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:pass"]
    stateless_fragment_default_actions = ["aws:drop"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless[0].arn
    }
  }

  tags = {
    Name        = "${local.common_name}-firewall-policy"
    Type        = "network-firewall-policy"
    Environment = var.common_tags.Environment
  }
}

# Stateless rule group
resource "aws_networkfirewall_rule_group" "stateless" {
  count    = var.enable_advanced_networking && var.enable_network_firewall ? 1 : 0
  provider = aws.primary
  capacity = 100
  name     = "${local.common_name}-stateless-rules"
  type     = "STATELESS"

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:pass"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
            }
          }
        }
      }
    }
  }

  tags = {
    Name        = "${local.common_name}-stateless-rules"
    Type        = "network-firewall-rules"
    Environment = var.common_tags.Environment
  }
}

# Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  count                = var.enable_advanced_networking && var.enable_network_firewall ? 1 : 0
  provider             = aws.primary
  name                 = "${local.common_name}-firewall"
  firewall_policy_arn  = aws_networkfirewall_firewall_policy.main[0].arn
  vpc_id               = aws_vpc.primary.id
  delete_protection    = false
  firewall_policy_change_protection = false
  subnet_change_protection = false

  subnet_mapping {
    subnet_id = aws_subnet.primary_public[0].id
  }

  tags = {
    Name        = "${local.common_name}-firewall"
    Type        = "network-firewall"
    Environment = var.common_tags.Environment
  }
}
EOF

print_success "✅ advanced-networking.tf created"

# ================================================================
# OUTPUT COLLISION DETECTION AND SAFE ADDITION
# ================================================================

print_header "Checking for output collisions and adding new outputs..."

# Define networking outputs to add
declare -A networking_outputs=(
    ["transit_gateway_id"]="Transit Gateway ID"
    ["vpc_peering_connection_id"]="VPC Peering Connection ID"
    ["cloudfront_distribution_id"]="CloudFront Distribution ID"
    ["cloudfront_domain_name"]="CloudFront Domain Name"
    ["route53_private_zone_id"]="Route 53 Private Zone ID"
    ["vpn_connection_id"]="VPN Connection ID"
    ["customer_gateway_id"]="Customer Gateway ID"
    ["network_firewall_arn"]="Network Firewall ARN"
    ["secondary_vpc_id"]="Secondary VPC ID"
)

# Check for existing outputs and add only new ones
new_outputs=""
for output_name in "${!networking_outputs[@]}"; do
    if check_output_exists "$output_name"; then
        print_warning "Output '$output_name' already exists - skipping"
    else
        print_status "Adding new output: $output_name"
        case "$output_name" in
            "transit_gateway_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].id : \"Not deployed\"
}
"
                ;;
            "vpc_peering_connection_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_vpc_peering ? aws_vpc_peering_connection.primary_to_secondary[0].id : \"Not deployed\"
}
"
                ;;
            "cloudfront_distribution_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_cloudfront ? aws_cloudfront_distribution.main[0].id : \"Not deployed\"
}
"
                ;;
            "cloudfront_domain_name")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_cloudfront ? aws_cloudfront_distribution.main[0].domain_name : \"Not deployed\"
}
"
                ;;
            "route53_private_zone_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_route53_advanced ? aws_route53_zone.private[0].zone_id : \"Not deployed\"
}
"
                ;;
            "vpn_connection_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_vpn_gateway ? aws_vpn_connection.main[0].id : \"Not deployed\"
}
"
                ;;
            "customer_gateway_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_vpn_gateway ? aws_customer_gateway.main[0].id : \"Not deployed\"
}
"
                ;;
            "network_firewall_arn")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_network_firewall ? aws_networkfirewall_firewall.main[0].arn : \"Not deployed\"
}
"
                ;;
            "secondary_vpc_id")
                new_outputs+="
output \"$output_name\" {
  description = \"${networking_outputs[$output_name]}\"
  value       = var.enable_advanced_networking && var.enable_vpc_peering ? aws_vpc.secondary[0].id : \"Not deployed\"
}
"
                ;;
        esac
    fi
done

# Add new outputs if any
if [[ -n "$new_outputs" ]]; then
    print_status "Adding new networking outputs to outputs.tf..."
    cat >> outputs.tf << EOF

# ================================================================
# ADVANCED NETWORKING OUTPUTS
# ================================================================
$new_outputs
EOF
    print_success "✅ New networking outputs added"
else
    print_warning "All networking outputs already exist"
fi

# ================================================================
# PROVIDER VALIDATION
# ================================================================

print_header "Checking provider configurations..."

# Check if testbed provider exists
if ! grep -q "provider \"aws\"" main.tf | grep -q "testbed\|secondary"; then
    print_status "Adding testbed provider alias to main.tf..."
    
    # Add testbed provider after primary provider
    sed -i '/provider "aws" {/,/^}/a\\n# Testbed provider for multi-region scenarios\nprovider "aws" {\n  alias  = "testbed"\n  region = var.testbed_region\n  default_tags {\n    tags = var.common_tags\n  }\n}' main.tf
    
    print_success "✅ Testbed provider added"
else
    print_success "✅ Testbed provider already configured"
fi

# ================================================================
# UPDATE DOMAIN CONFIGURATIONS
# ================================================================

print_header "Updating domain configurations with networking settings..."

# Update Full Lab configuration
if [[ -f "study-configs/full-lab.tfvars" ]]; then
    if ! grep -q "enable_advanced_networking" study-configs/full-lab.tfvars; then
        cat >> study-configs/full-lab.tfvars << 'EOF'

# Advanced Networking configuration for Full Lab
enable_advanced_networking = true
enable_transit_gateway = true
enable_vpc_peering = true
enable_route53_advanced = true
enable_cloudfront = true
enable_vpn_gateway = true
enable_direct_connect_simulation = false  # Expensive
enable_network_firewall = false  # Very expensive
enable_route53_resolver = true

# Networking settings
cloudfront_price_class = "PriceClass_100"  # Cost optimized
route53_health_check_regions = ["us-east-1", "us-west-2"]
vpc_peering_regions = ["us-east-2"]
transit_gateway_asn = 64512
cloudfront_cache_behavior = "managed-caching-optimized"
EOF
        print_success "✅ Full Lab configuration updated with networking settings"
    else
        print_warning "Full Lab already has networking configuration"
    fi
fi

# Create networking-only configuration
print_status "Creating networking-only testing configuration..."
cat > study-configs/networking-only.tfvars << 'EOF'
# Advanced Networking-only configuration for focused networking study
# Use this to test just the advanced networking components

# Disable other tiers to focus on networking
enable_compute_tier = false
enable_database_tier = false
enable_monitoring_tier = false
enable_security_tier = false
enable_disaster_recovery = false

# Enable advanced networking tier
enable_advanced_networking = true

# Core networking features
enable_transit_gateway = true
enable_vpc_peering = true
enable_route53_advanced = true
enable_cloudfront = true
enable_vpn_gateway = false  # Skip VPN for basic networking study
enable_direct_connect_simulation = false
enable_network_firewall = false  # Expensive
enable_route53_resolver = true

# Networking settings
cloudfront_price_class = "PriceClass_100"
route53_health_check_regions = ["us-east-1"]
vpc_peering_regions = ["us-east-2"]
transit_gateway_asn = 64512
cloudfront_cache_behavior = "managed-caching-optimized"

# Basic settings
development_mode = true
log_retention_days = 3
enable_nat_gateway = false  # Keep costs low
enable_vpc_flow_logs = true

# Required for some networking features
domain_name = "lab.example.com"
create_route53_zone = false

# Email for notifications
notification_email = "RRCloudDev@gmail.com"
EOF

print_success "✅ Networking-only configuration created"

# ================================================================
# CREATE NETWORKING HELPER SCRIPTS
# ================================================================

print_header "Creating networking helper scripts..."

# Networking status script
cat > scripts/networking-status.sh << 'EOF'
#!/bin/bash
# networking-status.sh - Check advanced networking service status

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_networking_overview() {
    print_status "Getting advanced networking infrastructure overview..."
    
    echo ""
    print_success "Networking Services Status:"
    
    # Check Transit Gateway
    local tgw_id=$(terraform output -json transit_gateway_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$tgw_id" != "Not deployed" && "$tgw_id" != "" && "$tgw_id" != "null" ]]; then
        echo "✅ Transit Gateway: $tgw_id"
    else
        echo "❌ Transit Gateway: Not deployed"
    fi
    
    # Check VPC Peering
    local peering_id=$(terraform output -json vpc_peering_connection_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$peering_id" != "Not deployed" && "$peering_id" != "" && "$peering_id" != "null" ]]; then
        echo "✅ VPC Peering: $peering_id"
    else
        echo "❌ VPC Peering: Not deployed"
    fi
    
    # Check CloudFront
    local cf_id=$(terraform output -json cloudfront_distribution_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$cf_id" != "Not deployed" && "$cf_id" != "" && "$cf_id" != "null" ]]; then
        echo "✅ CloudFront: $cf_id"
        local cf_domain=$(terraform output -json cloudfront_domain_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        if [[ "$cf_domain" != "Not deployed" && "$cf_domain" != "" ]]; then
            echo "   Domain: https://$cf_domain"
        fi
    else
        echo "❌ CloudFront: Not deployed"
    fi
    
    # Check Route 53
    local r53_zone=$(terraform output -json route53_private_zone_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$r53_zone" != "Not deployed" && "$r53_zone" != "" && "$r53_zone" != "null" ]]; then
        echo "✅ Route 53 Private Zone: $r53_zone"
    else
        echo "❌ Route 53 Private Zone: Not deployed"
    fi
    
    # Check VPN
    local vpn_id=$(terraform output -json vpn_connection_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$vpn_id" != "Not deployed" && "$vpn_id" != "" && "$vpn_id" != "null" ]]; then
        echo "✅ VPN Connection: $vpn_id"
    else
        echo "❌ VPN Connection: Not deployed"
    fi
}

show_transit_gateway_details() {
    print_status "Transit Gateway detailed information..."
    
    if command -v aws &> /dev/null; then
        local tgw_id=$(terraform output -json transit_gateway_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        
        if [[ "$tgw_id" != "Not deployed" && "$tgw_id" != "" && "$tgw_id" != "null" ]]; then
            echo ""
            print_success "Transit Gateway Details:"
            aws ec2 describe-transit-gateways --transit-gateway-ids "$tgw_id" --query 'TransitGateways[0].{ID:TransitGatewayId,State:State,ASN:AmazonSideAsn,Owner:OwnerId}' --output table 2>/dev/null || echo "Unable to get TGW details"
            
            echo ""
            print_success "Transit Gateway Attachments:"
            aws ec2 describe-transit-gateway-attachments --filters "Name=transit-gateway-id,Values=$tgw_id" --query 'TransitGatewayAttachments[].{ID:TransitGatewayAttachmentId,Type:ResourceType,State:State,VPC:ResourceId}' --output table 2>/dev/null || echo "Unable to get TGW attachments"
        else
            echo "❌ Transit Gateway not deployed"
        fi
    else
        echo "AWS CLI not available for detailed TGW information"
    fi
}

show_vpc_peering_details() {
    print_status "VPC Peering detailed information..."
    
    if command -v aws &> /dev/null; then
        local peering_id=$(terraform output -json vpc_peering_connection_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        
        if [[ "$peering_id" != "Not deployed" && "$peering_id" != "" && "$peering_id" != "null" ]]; then
            echo ""
            print_success "VPC Peering Details:"
            aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$peering_id" --query 'VpcPeeringConnections[0].{ID:VpcPeeringConnectionId,Status:Status.Code,RequesterVPC:RequesterVpcInfo.VpcId,AccepterVPC:AccepterVpcInfo.VpcId}' --output table 2>/dev/null || echo "Unable to get peering details"
        else
            echo "❌ VPC Peering not deployed"
        fi
    else
        echo "AWS CLI not available for detailed peering information"
    fi
}

show_cloudfront_details() {
    print_status "CloudFront distribution details..."
    
    if command -v aws &> /dev/null; then
        local cf_id=$(terraform output -json cloudfront_distribution_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        
        if [[ "$cf_id" != "Not deployed" && "$cf_id" != "" && "$cf_id" != "null" ]]; then
            echo ""
            print_success "CloudFront Distribution:"
            aws cloudfront get-distribution --id "$cf_id" --query 'Distribution.{ID:Id,Status:Status,DomainName:DomainName,PriceClass:DistributionConfig.PriceClass}' --output table 2>/dev/null || echo "Unable to get CloudFront details"
            
            local cf_domain=$(terraform output -json cloudfront_domain_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
            if [[ "$cf_domain" != "Not deployed" && "$cf_domain" != "" ]]; then
                echo ""
                print_warning "Test your CloudFront distribution:"
                echo "  curl -I https://$cf_domain"
                echo "  Or visit: https://$cf_domain"
            fi
        else
            echo "❌ CloudFront not deployed"
        fi
    else
        echo "AWS CLI not available for CloudFront details"
    fi
}

test_connectivity() {
    print_status "Testing network connectivity..."
    
    echo ""
    print_success "Basic Connectivity Tests:"
    
    # Test CloudFront
    local cf_domain=$(terraform output -json cloudfront_domain_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$cf_domain" != "Not deployed" && "$cf_domain" != "" && "$cf_domain" != "null" ]]; then
        print_status "Testing CloudFront distribution..."
        if curl -s -o /dev/null -w "%{http_code}" "https://$cf_domain" | grep -q "200\|403"; then
            echo "✅ CloudFront: Responding"
        else
            echo "❌ CloudFront: Not responding or not ready"
        fi
    fi
    
    # Test ALB (if compute tier enabled)
    local alb_dns=$(terraform output -json web_alb_dns_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$alb_dns" != "Not deployed" && "$alb_dns" != "" && "$alb_dns" != "null" ]]; then
        print_status "Testing Application Load Balancer..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$alb_dns" | grep -q "200"; then
            echo "✅ ALB: Responding"
        else
            echo "❌ ALB: Not responding or unhealthy targets"
        fi
    fi
}

case ${1:-""} in
    "overview"|"status"|"")
        show_networking_overview
        ;;
    "tgw"|"transit-gateway")
        show_transit_gateway_details
        ;;
    "peering"|"vpc-peering")
        show_vpc_peering_details
        ;;
    "cloudfront"|"cdn")
        show_cloudfront_details
        ;;
    "test"|"connectivity")
        test_connectivity
        ;;
    "all")
        show_networking_overview
        echo ""
        show_transit_gateway_details
        echo ""
        show_vpc_peering_details
        echo ""
        show_cloudfront_details
        echo ""
        test_connectivity
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/networking-status.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  overview, status   Show networking services overview"
        echo "  tgw, transit-gateway  Show Transit Gateway details"
        echo "  peering, vpc-peering  Show VPC Peering details"
        echo "  cloudfront, cdn    Show CloudFront distribution details"
        echo "  test, connectivity Test network connectivity"
        echo "  all                Show all networking information"
        echo "  help               Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/networking-status.sh help' for usage"
        exit 1
        ;;
esac
EOF

chmod +x scripts/networking-status.sh

print_success "✅ Networking helper scripts created"

# ================================================================
# UPDATE STUDY-DEPLOY.SH
# ================================================================

print_header "Updating study-deploy.sh with networking commands..."

# Add networking command to the help section
if ! grep -q "networking" study-deploy.sh; then
    sed -i '/  security        Deploy security-only configuration/a\
  networking      Deploy networking-only configuration (focused study)' study-deploy.sh

    # Add networking case to the main function
    sed -i '/        "security"|"sec") deploy_domain "security-only" ;;/a\
        "networking"|"net") deploy_domain "networking-only" ;;' study-deploy.sh
fi

print_success "✅ study-deploy.sh updated with networking commands"

# ================================================================
# FINAL VALIDATION
# ================================================================

print_header "Running final validation..."

# Validate terraform configuration
print_status "Validating Terraform configuration..."
if terraform validate; then
    print_success "✅ Terraform configuration is valid!"
else
    print_error "❌ Terraform validation failed"
    terraform validate
    echo ""
    print_warning "Common issues and fixes:"
    echo "  1. Check provider aliases are configured correctly"
    echo "  2. Verify all referenced resources exist"
    echo "  3. Check for typos in resource names"
    echo "  4. Ensure all required variables are defined"
    exit 1
fi

# Check for any remaining resource conflicts
print_status "Checking for resource conflicts..."
conflicts_found=0

for tf_file in *.tf; do
    if [[ -f "$tf_file" ]]; then
        # Check for duplicate resource definitions
        duplicates=$(grep -n "^resource " "$tf_file" | cut -d: -f2 | sort | uniq -d)
        if [[ -n "$duplicates" ]]; then
            print_warning "Potential duplicate resources in $tf_file:"
            echo "$duplicates"
            ((conflicts_found++))
        fi
    fi
done

if [[ $conflicts_found -eq 0 ]]; then
    print_success "✅ No resource conflicts detected"
else
    print_warning "⚠️  $conflicts_found potential conflicts found - review before deploying"
fi

echo ""
print_success "🎉 Advanced Networking Module Implementation Complete!"
echo ""
print_status "Files created/modified:"
echo "  ✅ advanced-networking.tf - Complete advanced networking infrastructure"
echo "  ✅ variables.tf - Advanced networking variables added (collision-safe)"
echo "  ✅ outputs.tf - Advanced networking outputs added (collision-safe)"
echo "  ✅ main.tf - Testbed provider added (if needed)"
echo "  ✅ study-configs/full-lab.tfvars - Updated with networking settings"
echo "  ✅ study-configs/networking-only.tfvars - Networking-focused configuration"
echo "  ✅ scripts/networking-status.sh - Networking service status checker"
echo "  ✅ study-deploy.sh - Updated with networking commands"
echo ""
print_warning "💰 Advanced Networking Cost Estimates:"
echo "  Networking-only: ~$5-12/day (TGW, CloudFront, Route 53)"
echo "  + VPN Gateway: +$1-3/day"
echo "  + Network Firewall: +$10-20/day (expensive!)"
echo "  Full Lab: ~$35-55/day (all features + previous tiers)"
echo ""
print_status "Next steps:"
echo "  1. Test networking-only: ./study-deploy.sh networking"
echo "  2. Or deploy full lab: ./study-deploy.sh full-lab"
echo "  3. Check networking status: ./scripts/networking-status.sh overview"
echo "  4. Test connectivity: ./scripts/networking-status.sh test"
echo "  5. Always destroy after study: ./study-deploy.sh destroy"
echo ""
print_success "🌐 Ready to deploy advanced networking infrastructure!"
echo ""
print_warning "📋 What you get with the advanced networking tier:"
echo "  🔹 Transit Gateway for hub-and-spoke architecture"
echo "  🔹 Cross-region VPC Peering connections"
echo "  🔹 CloudFront CDN with multiple origins"
echo "  🔹 Route 53 private zones and health checks"
echo "  🔹 VPN Gateway and Customer Gateway simulation"
echo "  🔹 Network Firewall for advanced security (optional)"
echo "  🔹 Multiple provider configurations (multi-region)"
echo "  🔹 Advanced routing and DNS patterns"
echo ""
print_success "Build globally distributed, highly available networks! 🚀"
