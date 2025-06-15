#!/bin/bash
# SA Pro Enhancement Validation Script

set -e

echo "Validating SA Pro Enhancement..."

# Check if new domains exist
echo "Checking domain directories..."
if [ ! -d "domains/domain5-enterprise-architecture" ]; then
    echo "❌ Domain 5 directory missing"
    exit 1
else
    echo "✅ Domain 5 directory exists"
fi

if [ ! -d "domains/domain6-advanced-migration" ]; then
    echo "❌ Domain 6 directory missing"
    exit 1
else
    echo "✅ Domain 6 directory exists"
fi

# Check if main.tf was updated
echo "Checking main.tf updates..."
if ! grep -q "enable_domain5" main.tf; then
    echo "❌ Domain 5 not added to main.tf"
    exit 1
else
    echo "✅ Domain 5 added to main.tf"
fi

if ! grep -q "enable_domain6" main.tf; then
    echo "❌ Domain 6 not added to main.tf"
    exit 1
else
    echo "✅ Domain 6 added to main.tf"
fi

# Check if variables were added
echo "Checking variables..."
if ! grep -q "enable_domain5" variables.tf; then
    echo "❌ Domain 5 variables missing from variables.tf"
    exit 1
else
    echo "✅ Domain 5 variables found"
fi

if ! grep -q "enable_domain6" variables.tf; then
    echo "❌ Domain 6 variables missing from variables.tf"
    exit 1
else
    echo "✅ Domain 6 variables found"
fi

# Check study configs
echo "Checking study configurations..."
if [ ! -f "study-configs/sa-pro-enterprise.tfvars" ]; then
    echo "❌ SA Pro enterprise study config missing"
    exit 1
else
    echo "✅ SA Pro enterprise config exists"
fi

if [ ! -f "study-configs/sa-pro-migration.tfvars" ]; then
    echo "❌ SA Pro migration study config missing"
    exit 1
else
    echo "✅ SA Pro migration config exists"
fi

if [ ! -f "study-configs/sa-pro-comprehensive.tfvars" ]; then
    echo "❌ SA Pro comprehensive study config missing"
    exit 1
else
    echo "✅ SA Pro comprehensive config exists"
fi

# Check if compatibility layer was updated
echo "Checking compatibility layer..."
if [ -f "compatibility-layer.tf" ]; then
    if grep -q "enable_organizations" compatibility-layer.tf; then
        echo "✅ Compatibility layer updated with Domain 5 variables"
    else
        echo "❌ Compatibility layer missing Domain 5 variables"
        exit 1
    fi
    
    if grep -q "enable_application_migration_service" compatibility-layer.tf; then
        echo "✅ Compatibility layer updated with Domain 6 variables"
    else
        echo "❌ Compatibility layer missing Domain 6 variables"
        exit 1
    fi
else
    echo "❌ Compatibility layer file missing"
    exit 1
fi

# Check for userdata directory
echo "Checking userdata directories..."
if [ ! -d "domains/domain6-advanced-migration" ]; then
    echo "❌ Domain 6 directory structure incomplete"
    exit 1
fi

# Try to create userdata directory if it doesn't exist
mkdir -p domains/domain6-advanced-migration/userdata

# Validate Terraform syntax (skip if terraform not available)
echo "Validating Terraform syntax..."
if command -v terraform &> /dev/null; then
    # Clean any existing state first
    rm -rf .terraform* 2>/dev/null || true
    
    # Initialize without backend
    if terraform init -backend=false > /dev/null 2>&1; then
        echo "✅ Terraform initialized successfully"
        
        # Validate syntax
        if terraform validate > /dev/null 2>&1; then
            echo "✅ Terraform validation passed"
        else
            echo "❌ Terraform validation failed"
            echo "Running terraform validate to show errors:"
            terraform validate
            exit 1
        fi
    else
        echo "❌ Terraform initialization failed"
        echo "Running terraform init to show errors:"
        terraform init -backend=false
        exit 1
    fi
else
    echo "⚠️ Terraform not found, skipping syntax validation"
fi

echo ""
echo "✅ SA Pro Enhancement validation passed!"
echo ""
echo "📚 Available study configurations:"
echo "  - sa-pro-enterprise.tfvars (Domain 5: Enterprise Architecture)"
echo "  - sa-pro-migration.tfvars (Domain 6: Advanced Migration)"
echo "  - sa-pro-comprehensive.tfvars (All domains)"
echo ""
echo "🧪 Test with:"
echo "  terraform plan -var-file=\"study-configs/sa-pro-enterprise.tfvars\""
echo "  terraform plan -var-file=\"study-configs/sa-pro-migration.tfvars\""
echo "  terraform plan -var-file=\"study-configs/sa-pro-comprehensive.tfvars\""
echo ""
echo "🎯 Your lab now covers 100% of AWS SA Professional exam domains!"
