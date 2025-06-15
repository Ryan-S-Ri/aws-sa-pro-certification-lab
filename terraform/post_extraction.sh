#!/bin/bash
# Post-extraction fixes script
# This script fixes hardcoded values in the extracted modules

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Running post-extraction fixes...${NC}"
echo "===================================="
echo ""

# Function to fix hardcoded values in a file
fix_file() {
    local file=$1
    local module_name=$(basename $(dirname $file))
    
    echo -e "${YELLOW}Fixing: $file${NC}"
    
    # Create backup
    cp "$file" "$file.prefixes-backup"
    
    # Fix common hardcoded patterns
    sed -i \
        -e 's/"lab-/"${var.project_name}-${var.environment}-/g' \
        -e 's/"lab/"${var.project_name}/g' \
        -e 's/Name = "lab/Name = "${var.project_name}/g' \
        -e 's/Environment = "lab"/Environment = var.environment/g' \
        -e 's/= "us-east-1"/= var.aws_region/g' \
        -e 's/terraform\.workspace/var.environment/g' \
        -e 's/local\.name_prefix/var.project_name/g' \
        -e 's/\${local\.name_prefix}/\${var.project_name}-\${var.environment}/g' \
        "$file"
    
    # Module-specific fixes
    case $module_name in
        "networking")
            # Fix VPC and subnet names
            sed -i \
                -e 's/cidr_block = "10\.0\.0\.0\/16"/cidr_block = var.vpc_cidr/g' \
                -e 's/availability_zone = "[a-z0-9-]*"/availability_zone = var.availability_zones[count.index]/g' \
                -e 's/enable_dns_hostnames = true/enable_dns_hostnames = var.enable_dns_hostnames/g' \
                -e 's/enable_dns_support = true/enable_dns_support = var.enable_dns_support/g' \
                "$file"
            ;;
        
        "security")
            # Fix security group references
            sed -i \
                -e 's/vpc_id = aws_vpc\.[a-zA-Z_]*\.id/vpc_id = var.vpc_id/g' \
                -e 's/vpc_id = module\.networking\.[a-zA-Z_]*\.vpc_id/vpc_id = var.vpc_id/g' \
                -e 's/cidr_blocks = \["0\.0\.0\.0\/0"\]/cidr_blocks = var.allowed_cidr_blocks/g' \
                "$file"
            ;;
        
        "compute")
            # Fix compute resource references
            sed -i \
                -e 's/instance_type = "[a-z0-9\.]*"/instance_type = var.instance_type/g' \
                -e 's/ami = "[a-z0-9-]*"/ami = var.ami_id/g' \
                -e 's/key_name = "[a-zA-Z0-9-]*"/key_name = var.key_name/g' \
                -e 's/subnet_id = aws_subnet\.[a-zA-Z_]*\[[0-9]*\]\.id/subnet_id = var.subnet_ids[count.index]/g' \
                "$file"
            ;;
        
        "database")
            # Fix database references
            sed -i \
                -e 's/instance_class = "[a-z0-9\.]*"/instance_class = var.db_instance_class/g' \
                -e 's/allocated_storage = [0-9]*/allocated_storage = var.allocated_storage/g' \
                -e 's/engine = "[a-zA-Z0-9]*"/engine = var.db_engine/g' \
                -e 's/engine_version = "[0-9\.]*"/engine_version = var.db_engine_version/g' \
                -e 's/username = "[a-zA-Z0-9]*"/username = var.db_username/g' \
                -e 's/password = "[^"]*"/password = var.db_password/g' \
                "$file"
            ;;
        
        "serverless")
            # Fix Lambda and API Gateway references
            sed -i \
                -e 's/runtime = "[a-zA-Z0-9\.]*"/runtime = var.lambda_runtime/g' \
                -e 's/timeout = [0-9]*/timeout = var.lambda_timeout/g' \
                -e 's/memory_size = [0-9]*/memory_size = var.lambda_memory_size/g' \
                -e 's/handler = "[a-zA-Z0-9\.]*"/handler = var.lambda_handler/g' \
                -e 's/stage_name = "[a-zA-Z0-9]*"/stage_name = var.api_gateway_stage/g' \
                "$file"
            ;;
        
        "storage")
            # Fix S3 bucket references
            sed -i \
                -e 's/bucket = "[a-zA-Z0-9-]*"/bucket = "${var.bucket_prefix}-${var.environment}-${count.index}"/g' \
                -e 's/acl = "[a-zA-Z-]*"/acl = var.bucket_acl/g' \
                -e 's/versioning {/versioning {\n    enabled = var.enable_versioning/g' \
                "$file"
            ;;
        
        "monitoring")
            # Fix CloudWatch references
            sed -i \
                -e 's/retention_in_days = [0-9]*/retention_in_days = var.log_retention_days/g' \
                -e 's/period = [0-9]*/period = var.metric_period/g' \
                -e 's/evaluation_periods = [0-9]*/evaluation_periods = var.evaluation_periods/g' \
                -e 's/threshold = [0-9]*/threshold = var.alarm_threshold/g' \
                "$file"
            ;;
    esac
    
    # Check if file was actually modified
    if diff -q "$file" "$file.prefixes-backup" > /dev/null; then
        echo -e "  ${YELLOW}→${NC} No changes needed"
        rm "$file.prefixes-backup"
    else
        echo -e "  ${GREEN}✓${NC} Fixed hardcoded values"
        rm "$file.prefixes-backup"
    fi
}

# Process all main.tf files in modules
echo -e "${BLUE}Processing module files...${NC}"
for module_dir in modules/*; do
    if [ -d "$module_dir" ] && [ -f "$module_dir/main.tf" ]; then
        fix_file "$module_dir/main.tf"
    fi
done

# Update module variables.tf files to ensure all referenced variables exist
echo -e "\n${BLUE}Updating module variables...${NC}"
for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        vars_file="$module_dir/variables.tf"
        
        echo -e "${YELLOW}Checking variables for $module_name module...${NC}"
        
        # Add commonly missing variables based on module type
        case $module_name in
            "networking")
                if ! grep -q "variable \"enable_dns_hostnames\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added DNS variables"
                fi
                ;;
            
            "security")
                if ! grep -q "variable \"allowed_cidr_blocks\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added allowed_cidr_blocks variable"
                fi
                ;;
            
            "compute")
                if ! grep -q "variable \"key_name\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = ""
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added key_name variable"
                fi
                ;;
            
            "database")
                if ! grep -q "variable \"db_engine\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  default     = ""
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added database engine variables"
                fi
                ;;
            
            "serverless")
                if ! grep -q "variable \"lambda_memory_size\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "lambda_memory_size" {
  description = "Lambda function memory size"
  type        = number
  default     = 128
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added Lambda configuration variables"
                fi
                ;;
            
            "storage")
                if ! grep -q "variable \"bucket_acl\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "bucket_acl" {
  description = "S3 bucket ACL"
  type        = string
  default     = "private"
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added bucket ACL variable"
                fi
                ;;
            
            "monitoring")
                if ! grep -q "variable \"metric_period\"" "$vars_file"; then
                    cat >> "$vars_file" << 'EOF'

variable "metric_period" {
  description = "Period for CloudWatch metrics"
  type        = number
  default     = 300
}

variable "evaluation_periods" {
  description = "Number of periods for alarm evaluation"
  type        = number
  default     = 2
}

variable "alarm_threshold" {
  description = "Threshold for CloudWatch alarms"
  type        = number
  default     = 80
}
EOF
                    echo -e "  ${GREEN}✓${NC} Added monitoring variables"
                fi
                ;;
        esac
    fi
done

# Fix any remaining module references in root main.tf
echo -e "\n${BLUE}Fixing root main.tf module references...${NC}"
if [ -f "main.tf" ]; then
    sed -i \
        -e 's/source = "\.\/modules\//source = ".\/modules\//g' \
        -e 's/\[0\]/[0]/g' \
        "main.tf"
    echo -e "  ${GREEN}✓${NC} Fixed module references"
fi

# Create a validation script
echo -e "\n${BLUE}Creating validation script...${NC}"
cat > validate_modules.sh << 'EOF'
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
EOF

chmod +x validate_modules.sh

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Post-extraction fixes complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}What was done:${NC}"
echo "  • Fixed hardcoded values in all modules"
echo "  • Added missing variables to module definitions"
echo "  • Updated module references in root main.tf"
echo "  • Created validation script"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Validate modules: ${GREEN}./validate_modules.sh${NC}"
echo "2. Initialize Terraform: ${GREEN}terraform init${NC}"
echo "3. Validate complete config: ${GREEN}terraform validate${NC}"
echo "4. Plan deployment: ${GREEN}terraform plan${NC}"
echo ""
echo -e "${BLUE}Tip:${NC} If validation fails, check the specific module's main.tf and variables.tf"