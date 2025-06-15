#!/bin/bash
# Validate all modules independently

echo "🔍 Validating Terraform Modules"
echo "=============================="

# Validate each module
for module in modules/*; do
    if [ -d "$module" ]; then
        module_name=$(basename "$module")
        echo -e "\nValidating $module_name module..."
        cd "$module"
        terraform init -backend=false > /dev/null 2>&1
        if terraform validate; then
            echo "  ✓ $module_name module is valid"
        else
            echo "  ✗ $module_name module has errors"
        fi
        cd - > /dev/null
    fi
done

echo -e "\nValidating root configuration..."
terraform init -backend=false > /dev/null 2>&1
if terraform validate; then
    echo "  ✓ Root configuration is valid"
else
    echo "  ✗ Root configuration has errors"
fi
