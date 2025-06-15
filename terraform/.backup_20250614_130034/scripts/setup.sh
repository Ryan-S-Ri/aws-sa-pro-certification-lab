#!/bin/bash

echo "🏗️  AWS Certification Lab - Setup Script (Pi Edition)"
echo "===================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }

# Check if we're in the terraform directory
if [ ! -f "terraform.tfvars.example" ]; then
    print_error "Please run this script from the terraform directory"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found!"
    echo "   Please copy terraform.tfvars.example to terraform.tfvars and configure it."
    echo "   Command: cp terraform.tfvars.example terraform.tfvars"
    exit 1
fi

# Check for email configuration
if grep -q "your-email@example.com" terraform.tfvars; then
    print_error "Please update your email address in terraform.tfvars"
    echo "   Find: notification_email = \"your-email@example.com\""
    echo "   Replace with your actual email address"
    exit 1
fi

# Check AWS credentials
print_info "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS credentials not configured. Please run 'aws configure'"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_REGION=$(aws configure get region)
print_status "AWS Account: $ACCOUNT_ID"
print_status "Current Region: $CURRENT_REGION"

# Check Terraform installation
print_info "Checking Terraform installation..."
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please run the pi-setup.sh script first."
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
print_status "Terraform version: $TERRAFORM_VERSION"

# Initialize Terraform
print_info "Initializing Terraform..."
if terraform init; then
    print_status "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi

# Validate configuration
print_info "Validating Terraform configuration..."
if terraform validate; then
    print_status "Terraform configuration is valid"
else
    print_error "Terraform validation failed"
    exit 1
fi

# Format check
print_info "Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    print_status "Terraform code is properly formatted"
else
    print_warning "Terraform code formatting issues detected"
    echo "   Run 'terraform fmt -recursive' to fix formatting"
fi

# Plan deployment (with Pi-optimized parallelism)
print_info "Planning deployment (Pi-optimized)..."
if terraform plan -parallelism=2 -out=tfplan; then
    print_status "Terraform plan completed successfully"
else
    print_error "Terraform planning failed"
    exit 1
fi

# Display cost warning
echo ""
echo "💰 COST WARNING (Pi Edition)"
echo "============================"
print_warning "This infrastructure will incur AWS charges!"
echo "   Pi-optimized estimated monthly cost: \$30-80 (depending on configuration)"
echo "   Monitor your costs at: https://console.aws.amazon.com/billing/"
echo ""
echo "💡 Pi cost optimization tips:"
echo "   - Current config uses development_mode = true"
echo "   - Monitor with: pi-cost"
echo "   - Run 'terraform destroy' when not actively studying"
echo ""

# Pi-specific performance info
echo "🥧 PI PERFORMANCE INFO"
echo "====================="
print_info "Terraform operations on Pi will be slower but fully functional"
echo "   - Expected apply time: 25-45 minutes"
echo "   - Monitor Pi temperature during deployment: watch 'vcgencmd measure_temp'"
echo "   - Use 'pi-status' to monitor system resources"
echo ""

# Deployment confirmation
echo "🚀 READY TO DEPLOY"
echo "=================="
print_status "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Review the plan output above"
echo "2. Run 'terraform apply tfplan' to deploy"
echo "3. Monitor deployment with 'pi-status' in another terminal"
echo "4. Estimated deployment time: 25-45 minutes on Pi"
echo ""
echo "⚠️  IMPORTANT REMINDERS:"
echo "   - Monitor Pi temperature during deployment"
echo "   - Use 'pi-cost' to monitor AWS costs daily"
echo "   - Use 'terraform destroy' to clean up when done"
echo "   - Pi will be perfect for always-on monitoring"
echo ""

read -p "Do you want to apply the plan now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Applying Terraform plan (Pi-optimized)..."
    if terraform apply -parallelism=2 tfplan; then
        print_status "Infrastructure deployed successfully! 🎉"
        echo ""
        echo "🎯 What's next:"
        echo "   - Check outputs: terraform output"
        echo "   - Monitor with: pi-dash"
        echo "   - Check costs with: pi-cost"
        echo "   - Start with scenarios in ../scenarios/"
        echo "   - Monitor costs regularly"
    else
        print_error "Terraform apply failed"
        exit 1
    fi
else
    print_info "Deployment skipped. Run 'terraform apply tfplan' when ready."
fi
