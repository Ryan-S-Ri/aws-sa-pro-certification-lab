#!/bin/bash
# Fix modules for fresh start

echo "Fixing modules for fresh deployment..."

# Add common locals to each module
for module in modules/*; do
    if [ -d "$module" ] && [ -f "$module/main.tf" ]; then
        # Add locals block at the beginning if it doesn't exist
        if ! grep -q "locals {" "$module/main.tf"; then
            cat > "$module/main.tf.new" << 'EOF'
locals {
  common_name = "${var.project_name}-${var.environment}"
}

EOF
            cat "$module/main.tf" >> "$module/main.tf.new"
            mv "$module/main.tf.new" "$module/main.tf"
            echo "✓ Added locals to $(basename $module)"
        fi
    fi
done

echo "✓ Modules updated for fresh start"
echo ""
echo "Note: Modules still need refactoring to:"
echo "- Remove references to resources in other modules"
echo "- Use proper input variables"
echo "- Create proper outputs"
