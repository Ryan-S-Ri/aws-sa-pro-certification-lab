#!/bin/bash
# Restore clean configuration after destroy

echo "Restoring clean configuration..."

# Remove destroy configuration
rm -f destroy_with_provider_alias.tf

# Remove provider files from modules
for module_dir in modules/*; do
    rm -f "$module_dir/providers.tf" 2>/dev/null || true
done

# Restore original configuration
if [ -d ".emergency_backup" ]; then
    mv .emergency_backup/*.tf . 2>/dev/null || true
    mv .emergency_backup/terraform.tfvars . 2>/dev/null || true
    rm -rf .emergency_backup
fi

# Clean state
rm -f terraform.tfstate*
rm -rf .terraform

# Initialize fresh
terraform init

echo "✅ Clean configuration restored!"
echo "You can now start fresh with: terraform plan"
