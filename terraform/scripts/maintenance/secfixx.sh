#!/bin/bash
# fix-security-tf.sh - Fix the data source error in security.tf

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "🔧 Fixing security.tf data source error..."

# Backup current security.tf
cp security.tf security.tf.error-backup-$(date +%Y%m%d-%H%M%S)

# Fix the data sources section
print_status "Fixing data sources in security.tf..."

# Replace the broken data sources section
cat > security.tf.tmp << 'EOF'
# security.tf - Security & Identity Infrastructure for SA Pro
# Comprehensive security setup covering IAM, ACM, Config, GuardDuty, and compliance

# ================================================================
# DATA SOURCES (Fixed)
# ================================================================

# Available AZs for multi-AZ resources
data "aws_availability_zones" "available" {
  provider = aws.primary
  state    = "available"
}

# ================================================================
# KMS KEYS FOR SECURITY SERVICES
# ================================================================
EOF

# Get everything after the data sources section from the original file
sed -n '/# KMS KEYS FOR SECURITY SERVICES/,$p' security.tf >> security.tf.tmp

# Replace the original file
mv security.tf.tmp security.tf

print_success "✅ security.tf data sources fixed"

# Validate
print_status "Running validation..."
if terraform validate; then
    print_success "✅ Terraform configuration is now valid!"
    echo ""
    print_success "🎉 All errors fixed! Ready to deploy:"
    echo "  terraform plan"
    echo "  ./study-deploy.sh security"
    echo "  ./study-deploy.sh domain1"
else
    print_warning "Still have issues, let me show the error:"
    terraform validate
    echo ""
    print_warning "If this doesn't work, try recreating security.tf:"
    echo "  rm security.tf"
    echo "  # Then re-run the security module implementation"
fi
