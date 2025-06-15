#!/bin/bash
# Nuclear Option - Clear state and start fresh
# WARNING: This will orphan all resources in AWS!

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}🚨 NUCLEAR OPTION - Clear State and Start Fresh${NC}"
echo "================================================"
echo ""
echo -e "${RED}WARNING: This will:${NC}"
echo "• Remove all resources from Terraform state"
echo "• Leave resources running in AWS (orphaned)"
echo "• Require manual cleanup in AWS Console"
echo "• Give you a completely fresh start"
echo ""
echo "Only use this if:"
echo "• This is a lab/test environment"
echo "• You're okay with manually cleaning up AWS resources"
echo "• You want to start completely fresh"
echo ""
read -p "Type 'NUCLEAR OPTION' to proceed: " confirm

if [ "$confirm" != "NUCLEAR OPTION" ]; then
    echo -e "\n${YELLOW}Cancelled. No changes made.${NC}"
    exit 0
fi

# Step 1: Backup current state
echo -e "\n${YELLOW}Step 1: Backing up current state...${NC}"
if [ -f "terraform.tfstate" ]; then
    mkdir -p state_backups
    cp terraform.tfstate "state_backups/terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "${GREEN}✓${NC} State backed up to state_backups/"
fi

# Step 2: List all resources in state
echo -e "\n${YELLOW}Step 2: Listing resources that will be orphaned...${NC}"
echo "The following resources will be orphaned in AWS:"
echo "================================================"
terraform state list 2>/dev/null || echo "No resources in state"
echo "================================================"

# Step 3: Remove all resources from state
echo -e "\n${YELLOW}Step 3: Removing all resources from state...${NC}"
resources=$(terraform state list 2>/dev/null || true)
if [ -n "$resources" ]; then
    for resource in $resources; do
        echo "Removing: $resource"
        terraform state rm "$resource" 2>/dev/null || true
    done
else
    echo "No resources to remove"
fi

# Step 4: Clean up Terraform files
echo -e "\n${YELLOW}Step 4: Cleaning up Terraform files...${NC}"
rm -f terraform.tfstate*
rm -rf .terraform
rm -f .terraform.lock.hcl

# Step 5: Restore clean configuration
echo -e "\n${YELLOW}Step 5: Restoring clean configuration...${NC}"
if [ -d "new_config_backup" ]; then
    rm -f main.tf variables.tf
    cp new_config_backup/*.tf . 2>/dev/null || true
    cp new_config_backup/terraform.tfvars . 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Clean configuration restored"
fi

# Remove provider.tf files from modules
for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        rm -f "$module_dir/providers.tf"
    fi
done

# Step 6: Create AWS resource cleanup checklist
echo -e "\n${YELLOW}Step 6: Creating AWS cleanup checklist...${NC}"
cat > AWS_CLEANUP_CHECKLIST.md << 'EOF'
# AWS Resource Cleanup Checklist

## Resources to manually delete in AWS Console:

### 1. EC2 Resources
- [ ] Terminate all EC2 instances
- [ ] Delete all Auto Scaling Groups
- [ ] Delete all Launch Templates
- [ ] Delete all Load Balancers (ALB, NLB)
- [ ] Delete all Target Groups
- [ ] Release all Elastic IPs
- [ ] Delete all Key Pairs
- [ ] Delete all Security Groups (except default)

### 2. VPC Resources
- [ ] Delete all NAT Gateways
- [ ] Delete all Internet Gateways
- [ ] Delete all Route Tables (except main)
- [ ] Delete all Subnets
- [ ] Delete all VPCs (except default)
- [ ] Delete all VPC Peering Connections

### 3. RDS/Database Resources
- [ ] Delete all RDS clusters and instances
- [ ] Delete all DB Subnet Groups
- [ ] Delete all DB Parameter Groups
- [ ] Delete all ElastiCache clusters
- [ ] Delete all ElastiCache Subnet Groups
- [ ] Delete all DynamoDB tables

### 4. Serverless Resources
- [ ] Delete all Lambda functions
- [ ] Delete all Lambda layers
- [ ] Delete all API Gateways (REST and HTTP)
- [ ] Delete all Step Functions
- [ ] Delete all EventBridge rules
- [ ] Delete all SQS queues
- [ ] Delete all SNS topics

### 5. Storage Resources
- [ ] Empty and delete all S3 buckets
- [ ] Delete all EFS file systems

### 6. Monitoring Resources
- [ ] Delete all CloudWatch Dashboards
- [ ] Delete all CloudWatch Alarms
- [ ] Delete all CloudWatch Log Groups
- [ ] Delete all SNS subscriptions

### 7. Security Resources
- [ ] Delete all Secrets in Secrets Manager
- [ ] Delete all KMS keys (schedule deletion)
- [ ] Delete all IAM roles (except AWS service-linked)
- [ ] Delete all IAM policies (except AWS managed)

## Order of Deletion:
1. Start with compute resources (EC2, Lambda)
2. Then databases and storage
3. Then networking (VPC last)
4. Finally security resources

## Tips:
- Check all regions if you deployed in multiple regions
- Some resources may have dependencies - delete in order
- KMS keys require scheduling deletion (7-30 days)
- Check AWS Cost Explorer tomorrow to ensure all resources are gone
EOF

echo -e "${GREEN}✓${NC} Created AWS_CLEANUP_CHECKLIST.md"

# Step 7: Initialize Terraform with clean state
echo -e "\n${YELLOW}Step 7: Initializing Terraform with clean state...${NC}"
terraform init

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Nuclear Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}What happened:${NC}"
echo "• All resources removed from Terraform state"
echo "• Terraform state cleared"
echo "• Clean configuration restored"
echo "• Ready to start fresh"
echo ""
echo -e "${RED}IMPORTANT - Manual Cleanup Required:${NC}"
echo "• Resources are still running in AWS!"
echo "• Check ${YELLOW}AWS_CLEANUP_CHECKLIST.md${NC} for cleanup steps"
echo "• Clean up resources in AWS Console to avoid charges"
echo ""
echo -e "${YELLOW}Next steps for fresh deployment:${NC}"
echo "1. Clean up AWS resources: ${GREEN}cat AWS_CLEANUP_CHECKLIST.md${NC}"
echo "2. Fix module configurations (they need refactoring)"
echo "3. Validate: ${GREEN}terraform validate${NC}"
echo "4. Plan: ${GREEN}terraform plan${NC}"
echo "5. Deploy: ${GREEN}terraform apply${NC}"

# Create module fix script
cat > fix_modules_for_fresh_start.sh << 'SCRIPT'
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
SCRIPT

chmod +x fix_modules_for_fresh_start.sh

echo -e "\n${BLUE}Additional helper created:${NC}"
echo "• ${GREEN}./fix_modules_for_fresh_start.sh${NC} - Basic fixes for modules"