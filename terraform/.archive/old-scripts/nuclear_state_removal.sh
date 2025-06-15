#!/bin/bash
# Nuclear option - remove all resources from state without destroying

echo "🚨 NUCLEAR OPTION - Remove all from state"
echo "========================================"
echo "This will orphan ALL resources in AWS!"
echo ""
read -p "Type 'REMOVE ALL FROM STATE' to proceed: " confirm

if [ "$confirm" = "REMOVE ALL FROM STATE" ]; then
    # Get all resources
    resources=$(terraform state list)
    
    # Remove each one
    for resource in $resources; do
        echo "Removing: $resource"
        terraform state rm "$resource" 2>/dev/null || true
    done
    
    echo ""
    echo "✅ All resources removed from state"
    echo "⚠️  Resources still exist in AWS - manual cleanup required!"
    
    # Clean up
    rm -f terraform.tfstate*
    ./restore_and_clean.sh
else
    echo "Cancelled."
fi
