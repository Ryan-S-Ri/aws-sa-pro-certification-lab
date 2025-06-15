#!/bin/bash
# Clean start and setup domain-based structure for AWS SA Pro lab

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}AWS SA Pro Lab - Clean Start & Domain Setup${NC}"
echo "==========================================="
echo ""

# Step 1: Complete cleanup
echo -e "${YELLOW}Step 1: Cleaning up old infrastructure...${NC}"

# Remove all Terraform state and files
rm -rf .terraform
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -f *.tfplan
rm -f state_list.txt

# Archive old cleanup scripts
mkdir -p .archive/old-scripts
mv *destroy*.sh .archive/old-scripts/ 2>/dev/null || true
mv *fix*.sh .archive/old-scripts/ 2>/dev/null || true
mv *clean*.sh .archive/old-scripts/ 2>/dev/null || true
mv nuke.sh .archive/old-scripts/ 2>/dev/null || true
mv nuclear*.sh .archive/old-scripts/ 2>/dev/null || true

# Clean up provider files from modules
for module_dir in modules/*; do
    if [ -d "$module_dir" ]; then
        rm -f "$module_dir/providers.tf" 2>/dev/null || true
    fi
done

echo -e "${GREEN}✓${NC} Cleanup complete"

# Step 2: Create domain-based structure
echo -e "\n${YELLOW}Step 2: Creating domain-based structure...${NC}"

# Create domain directories aligned with SAP-C02
mkdir -p domains/domain1-organizational-complexity/{scenarios,exercises,outputs}
mkdir -p domains/domain2-new-solutions/{scenarios,exercises,outputs}
mkdir -p domains/domain3-continuous-improvement/{scenarios,exercises,outputs}
mkdir -p domains/domain4-migration-modernization/{scenarios,exercises,outputs}

# Create shared infrastructure directory
mkdir -p shared-infrastructure/{networking,security,monitoring}

# Create exam preparation directories
mkdir -p exam-prep/{practice-scenarios,sample-architectures,cost-estimates}

echo -e "${GREEN}✓${NC} Domain structure created"

# Step 3: Create domain README files
echo -e "\n${YELLOW}Step 3: Creating domain documentation...${NC}"

# Domain 1 README
cat > domains/domain1-organizational-complexity/README.md << 'EOF'
# Domain 1: Design Solutions for Organizational Complexity (26%)

## Task Statements Covered

### 1.1: Architect network connectivity strategies
- Cross-account networking
- Transit Gateway implementations
- Direct Connect and VPN solutions
- Network segmentation strategies

### 1.2: Prescribe security controls
- Service Control Policies (SCPs)
- IAM policies and roles
- Cross-account access patterns
- Data encryption strategies

### 1.3: Design reliable and resilient architectures
- Multi-account backup strategies
- Cross-region replication
- Disaster recovery patterns
- High availability designs

### 1.4: Design a multi-account AWS environment
- AWS Organizations setup
- Control Tower implementation
- Landing Zone patterns
- Centralized logging and monitoring

### 1.5: Determine cost optimization opportunities
- Cross-account cost allocation
- Reserved capacity planning
- Savings Plans strategies
- Resource sharing patterns

## Exercises
1. Multi-account network connectivity lab
2. Cross-account IAM and SCP implementation
3. Organizations and Control Tower setup
4. Centralized logging architecture
5. Cost allocation and chargeback model

## Resources Created
- AWS Organizations with multiple OUs
- Transit Gateway with multiple attachments
- Cross-account IAM roles
- Service Control Policies
- Centralized CloudTrail and Config
EOF

# Domain 2 README
cat > domains/domain2-new-solutions/README.md << 'EOF'
# Domain 2: Design for New Solutions (29%)

## Task Statements Covered

### 2.1: Design deployment strategies
- Blue/green deployments
- Canary releases
- Feature toggles
- Immutable infrastructure

### 2.2: Design solutions to ensure business continuity
- Multi-region architectures
- Automated failover
- Data replication strategies
- RTO/RPO optimization

### 2.3: Determine security controls
- WAF implementations
- DDoS protection
- Certificate management
- Secrets rotation

### 2.4: Design solutions that meet reliability requirements
- Fault isolation boundaries
- Static stability patterns
- Circuit breakers
- Chaos engineering

### 2.5: Design solutions that meet performance objectives
- Caching strategies
- CDN implementations
- Database optimization
- Compute right-sizing

### 2.6: Determine cost optimization opportunities
- Spot instance strategies
- Serverless architectures
- Storage tiering
- License optimization

## Exercises
1. Multi-region active-active deployment
2. Automated blue/green deployment pipeline
3. Global content delivery implementation
4. Serverless event-driven architecture
5. High-performance computing cluster
6. Cost-optimized batch processing

## Resources Created
- Multi-region application deployment
- API Gateway with Lambda backends
- CloudFront distributions
- Auto Scaling with multiple strategies
- RDS with read replicas
- ElastiCache implementations
EOF

# Domain 3 README
cat > domains/domain3-continuous-improvement/README.md << 'EOF'
# Domain 3: Continuous Improvement for Existing Solutions (25%)

## Task Statements Covered

### 3.1: Determine strategy to improve overall operational excellence
- Automation opportunities
- Monitoring enhancements
- Operational metrics
- Process improvements

### 3.2: Determine strategy to improve security
- Security posture assessment
- Compliance automation
- Threat detection
- Incident response

### 3.3: Determine strategy to improve performance
- Performance baselines
- Bottleneck identification
- Scaling strategies
- Optimization techniques

### 3.4: Determine strategy to improve reliability
- Failure mode analysis
- Recovery automation
- Testing strategies
- Resilience patterns

### 3.5: Identify cost optimization opportunities
- Resource utilization analysis
- Waste elimination
- Purchasing options
- Architecture optimization

## Exercises
1. CloudWatch dashboard creation
2. Security Hub implementation
3. Performance testing with load generation
4. Chaos engineering experiments
5. Cost optimization assessment
6. Automated remediation workflows

## Resources Created
- Enhanced monitoring stack
- Security Hub with custom rules
- Systems Manager automation
- Cost anomaly detection
- Performance insights
- Automated backup solutions
EOF

# Domain 4 README
cat > domains/domain4-migration-modernization/README.md << 'EOF'
# Domain 4: Accelerate Workload Migration and Modernization (20%)

## Task Statements Covered

### 4.1: Select existing workloads for migration
- Discovery and assessment
- Dependency mapping
- Migration readiness
- Business case development

### 4.2: Determine optimal migration approach
- Rehost strategies
- Replatform options
- Refactor decisions
- Migration tools selection

### 4.3: Determine new architecture for existing workloads
- Containerization strategies
- Serverless transformation
- Microservices decomposition
- Data modernization

### 4.4: Identify opportunities for modernization
- Application decoupling
- Database modernization
- Analytics enablement
- AI/ML integration

## Exercises
1. Application discovery and assessment
2. Database migration with DMS
3. Container migration to ECS/EKS
4. Serverless transformation
5. Data lake implementation
6. Microservices refactoring

## Resources Created
- Migration Hub setup
- Database Migration Service
- Application Migration Service
- Container orchestration platform
- Data analytics pipeline
- Modernized application stack
EOF

echo -e "${GREEN}✓${NC} Documentation created"

# Step 4: Create main orchestrator
echo -e "\n${YELLOW}Step 4: Creating main orchestrator configuration...${NC}"

cat > main.tf << 'EOF'
# AWS SA Pro Lab - Main Orchestrator
# This file orchestrates the deployment of domain-specific infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider Configuration
provider "aws" {
  region = var.primary_region
  
  default_tags {
    tags = merge(
      var.common_tags,
      {
        Environment = var.environment
        Project     = "aws-sa-pro-lab"
      }
    )
  }
}

# Provider for DR region
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  
  default_tags {
    tags = merge(
      var.common_tags,
      {
        Environment = var.environment
        Project     = "aws-sa-pro-lab"
        Region      = "dr"
      }
    )
  }
}

# Shared Infrastructure
module "shared_infrastructure" {
  source = "./shared-infrastructure"
  count  = var.enable_shared_infrastructure ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  primary_region  = var.primary_region
  dr_region      = var.dr_region
  common_tags    = var.common_tags
}

# Domain 1: Organizational Complexity
module "domain1" {
  source = "./domains/domain1-organizational-complexity"
  count  = var.enable_domain1 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies from shared infrastructure
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids      = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []
}

# Domain 2: New Solutions
module "domain2" {
  source = "./domains/domain2-new-solutions"
  count  = var.enable_domain2 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids      = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []
}

# Domain 3: Continuous Improvement
module "domain3" {
  source = "./domains/domain3-continuous-improvement"
  count  = var.enable_domain3 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
}

# Domain 4: Migration and Modernization
module "domain4" {
  source = "./domains/domain4-migration-modernization"
  count  = var.enable_domain4 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids      = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []
}
EOF

# Create variables file
cat > variables.tf << 'EOF'
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "sa-pro-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
  default     = "us-west-2"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Terraform = "true"
    Purpose   = "aws-certification-lab"
  }
}

# Domain toggles
variable "enable_shared_infrastructure" {
  description = "Enable shared infrastructure deployment"
  type        = bool
  default     = true
}

variable "enable_domain1" {
  description = "Enable Domain 1: Organizational Complexity"
  type        = bool
  default     = false
}

variable "enable_domain2" {
  description = "Enable Domain 2: New Solutions"
  type        = bool
  default     = false
}

variable "enable_domain3" {
  description = "Enable Domain 3: Continuous Improvement"
  type        = bool
  default     = false
}

variable "enable_domain4" {
  description = "Enable Domain 4: Migration and Modernization"
  type        = bool
  default     = false
}

# Notification settings
variable "notification_email" {
  description = "Email for notifications"
  type        = string
  default     = ""
}
EOF

# Create terraform.tfvars template
cat > terraform.tfvars.template << 'EOF'
# AWS SA Pro Lab Configuration
# Copy this to terraform.tfvars and customize

project_name = "sa-pro-lab"
environment  = "lab"

# Regions
primary_region = "us-east-1"
dr_region     = "us-west-2"

# Enable/disable components
enable_shared_infrastructure = true
enable_domain1              = false
enable_domain2              = false
enable_domain3              = false
enable_domain4              = false

# Notifications
notification_email = "your-email@example.com"

# Tags
common_tags = {
  Terraform    = "true"
  Purpose      = "aws-certification-lab"
  Owner        = "your-name"
  CostCenter   = "training"
}
EOF

echo -e "${GREEN}✓${NC} Main orchestrator created"

# Step 5: Create deployment helper
echo -e "\n${YELLOW}Step 5: Creating deployment helper...${NC}"

cat > deploy.sh << 'EOF'
#!/bin/bash
# Deployment helper for AWS SA Pro Lab

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}AWS SA Pro Lab - Deployment Helper${NC}"
echo "=================================="
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from template...${NC}"
    cp terraform.tfvars.template terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars with your settings!${NC}"
    exit 1
fi

# Parse command line arguments
DOMAIN=""
ACTION="plan"

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --apply)
            ACTION="apply"
            shift
            ;;
        --destroy)
            ACTION="destroy"
            shift
            ;;
        --help)
            echo "Usage: ./deploy.sh [options]"
            echo ""
            echo "Options:"
            echo "  --domain [1-4|all]  Deploy specific domain or all"
            echo "  --apply             Apply the changes"
            echo "  --destroy           Destroy infrastructure"
            echo "  --help              Show this help"
            echo ""
            echo "Examples:"
            echo "  ./deploy.sh --domain 1          # Plan domain 1"
            echo "  ./deploy.sh --domain all --apply # Deploy all domains"
            echo "  ./deploy.sh --destroy           # Destroy everything"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Set domain flags
if [ "$DOMAIN" = "1" ]; then
    EXTRA_VARS="-var enable_domain1=true"
elif [ "$DOMAIN" = "2" ]; then
    EXTRA_VARS="-var enable_domain2=true"
elif [ "$DOMAIN" = "3" ]; then
    EXTRA_VARS="-var enable_domain3=true"
elif [ "$DOMAIN" = "4" ]; then
    EXTRA_VARS="-var enable_domain4=true"
elif [ "$DOMAIN" = "all" ]; then
    EXTRA_VARS="-var enable_domain1=true -var enable_domain2=true -var enable_domain3=true -var enable_domain4=true"
else
    EXTRA_VARS=""
fi

# Execute action
if [ "$ACTION" = "plan" ]; then
    echo -e "${YELLOW}Planning infrastructure...${NC}"
    terraform plan $EXTRA_VARS
elif [ "$ACTION" = "apply" ]; then
    echo -e "${YELLOW}Applying infrastructure...${NC}"
    terraform apply $EXTRA_VARS -auto-approve
elif [ "$ACTION" = "destroy" ]; then
    echo -e "${RED}Destroying infrastructure...${NC}"
    terraform destroy $EXTRA_VARS -auto-approve
fi

echo -e "${GREEN}✓${NC} Operation complete"
EOF

chmod +x deploy.sh

echo -e "${GREEN}✓${NC} Deployment helper created"

# Step 6: Create cost monitoring script
echo -e "\n${YELLOW}Step 6: Creating cost monitoring integration...${NC}"

cat > scripts/cost-monitor-enhanced.sh << 'EOF'
#!/bin/bash
# Enhanced cost monitoring for domain-based infrastructure

echo "AWS SA Pro Lab - Cost Monitor"
echo "============================"

# Get cost by domain tags
echo "Cost by Domain:"
aws ce get-cost-and-usage \
    --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --group-by Type=TAG,Key=Domain \
    --filter file://cost-filter.json 2>/dev/null || echo "No cost data available yet"

# Get cost by service
echo -e "\nCost by Service:"
aws ce get-cost-and-usage \
    --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --filter file://cost-filter.json 2>/dev/null || echo "No cost data available yet"

# Estimate monthly cost
echo -e "\nEstimated Monthly Cost:"
echo "Domain 1 (Organizational): ~$50-100/month"
echo "Domain 2 (New Solutions): ~$100-200/month"
echo "Domain 3 (Improvement): ~$75-150/month"
echo "Domain 4 (Migration): ~$100-200/month"
echo "Shared Infrastructure: ~$50-75/month"
echo ""
echo "Total if all domains active: ~$375-725/month"
EOF

chmod +x scripts/cost-monitor-enhanced.sh

echo -e "${GREEN}✓${NC} Cost monitoring created"

# Final summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ AWS SA Pro Lab Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Directory Structure Created:${NC}"
echo "📁 domains/"
echo "   ├── domain1-organizational-complexity/"
echo "   ├── domain2-new-solutions/"
echo "   ├── domain3-continuous-improvement/"
echo "   └── domain4-migration-modernization/"
echo "📁 shared-infrastructure/"
echo "📁 exam-prep/"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Copy and customize terraform.tfvars:"
echo "   ${GREEN}cp terraform.tfvars.template terraform.tfvars${NC}"
echo "   ${GREEN}vim terraform.tfvars${NC}"
echo ""
echo "2. Deploy shared infrastructure first:"
echo "   ${GREEN}./deploy.sh --apply${NC}"
echo ""
echo "3. Deploy specific domains:"
echo "   ${GREEN}./deploy.sh --domain 1 --apply${NC}"
echo ""
echo "4. Or deploy everything:"
echo "   ${GREEN}./deploy.sh --domain all --apply${NC}"
echo ""
echo -e "${BLUE}Your existing modules and scripts have been preserved!${NC}"
echo "- Modules are in: modules/"
echo "- Scripts are in: scripts/"
echo "- Study configs are in: study-configs/"
echo ""
echo -e "${RED}Remember:${NC} Always destroy resources when not studying to minimize costs!"
echo "   ${GREEN}./deploy.sh --destroy${NC}"