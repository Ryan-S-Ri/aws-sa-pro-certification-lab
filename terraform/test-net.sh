#!/bin/bash
# Test networking module only

echo "Testing networking module deployment..."

# Backup current tfvars
cp terraform.tfvars terraform.tfvars.backup

# Create networking-only tfvars
cat > terraform.tfvars << 'EOF'
# Project Configuration
project_name = "lab"
environment  = "dev"
aws_region   = "us-east-1"

# Module Enable Flags - Starting with networking only
enable_networking = true
enable_security   = false
enable_compute    = false
enable_database   = false
enable_storage    = false
enable_serverless = false
enable_monitoring = false

# Networking Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
enable_nat_gateway = false

# Security Configuration (for later)
enable_web_sg      = false
enable_database_sg = false

# Monitoring Configuration (for later)
enable_detailed_monitoring = false
alarm_email                = ""

# Storage Configuration (for later)
enable_versioning = true
enable_encryption = true

# Common Tags
common_tags = {
  Project     = "lab"
  Environment = "dev"
  Terraform   = "true"
  Purpose     = "Learning"
}
EOF

echo ""
echo "✅ Configuration set for networking only."
echo ""
echo "Your terraform.tfvars has been updated to enable ONLY the networking module."
echo ""
echo "Next steps:"
echo "1. Review the plan: terraform plan"
echo "2. If it looks good: terraform apply"
echo ""
echo "To restore your original settings later: cp terraform.tfvars.backup terraform.tfvars"