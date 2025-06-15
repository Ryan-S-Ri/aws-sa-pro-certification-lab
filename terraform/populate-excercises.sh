#!/bin/bash
# Script to populate exercises and scenarios for each domain

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Populating Exercises and Scenarios${NC}"
echo "=================================="
echo ""

# Domain 1 Exercises
echo -e "${YELLOW}Creating Domain 1 exercises...${NC}"

cat > domains/domain1-organizational-complexity/exercises/01-multi-account-setup.md << 'EOF'
# Exercise 1: Multi-Account AWS Organizations Setup

## Objective
Learn how to implement a multi-account strategy using AWS Organizations, including organizational units, service control policies, and cross-account access patterns.

## Prerequisites
- Domain 1 infrastructure deployed
- AWS CLI configured
- Appropriate IAM permissions

## Duration
45-60 minutes

## Tasks

### Task 1: Explore AWS Organizations Structure
1. Navigate to AWS Organizations console
2. Review the organizational structure
3. Check enabled policy types

```bash
# List organization details
aws organizations describe-organization

# List organizational units
aws organizations list-organizational-units-for-parent \
  --parent-id $(aws organizations list-roots --query 'Roots[0].Id' --output text)
```

### Task 2: Implement Service Control Policies
1. Create a new SCP to enforce encryption
2. Attach to Development OU
3. Test the policy effect

### Task 3: Cross-Account Access Configuration
1. Test cross-account role assumption
2. Configure AWS CLI profile for cross-account access
3. Verify access permissions

## Validation
- Verify Organizations structure is created
- Test SCP enforcement
- Successfully assume cross-account role

## Key Takeaways
- AWS Organizations provides hierarchical account management
- SCPs provide preventive guardrails
- Cross-account roles enable secure resource access
EOF

cat > domains/domain1-organizational-complexity/exercises/02-transit-gateway-lab.md << 'EOF'
# Exercise 2: Transit Gateway Configuration

## Objective
Configure and test Transit Gateway for multi-VPC and multi-account connectivity.

## Prerequisites
- Transit Gateway deployed
- Multiple VPCs available
- AWS CLI access

## Duration
30-45 minutes

## Tasks

### Task 1: Review Transit Gateway Configuration
```bash
# Get Transit Gateway ID
TGW_ID=$(terraform output -raw transit_gateway_id)

# Describe Transit Gateway
aws ec2 describe-transit-gateways --transit-gateway-ids $TGW_ID
```

### Task 2: Create VPC Attachment
1. Create a new VPC for testing
2. Attach to Transit Gateway
3. Configure routing

```bash
# Create test VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 --query 'Vpc.VpcId' --output text)

# Create subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.1.1.0/24 --query 'Subnet.SubnetId' --output text)

# Attach to Transit Gateway
aws ec2 create-transit-gateway-vpc-attachment \
  --transit-gateway-id $TGW_ID \
  --vpc-id $VPC_ID \
  --subnet-ids $SUBNET_ID
```

### Task 3: Configure Transit Gateway Routing
1. Review route tables
2. Add routes for inter-VPC communication
3. Test connectivity

## Validation
- Transit Gateway attachments are active
- Routes are properly configured
- Inter-VPC communication works

## Cleanup
```bash
# Remove test resources
aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id <attachment-id>
aws ec2 delete-subnet --subnet-id $SUBNET_ID
aws ec2 delete-vpc --vpc-id $VPC_ID
```
EOF

cat > domains/domain1-organizational-complexity/exercises/03-cost-allocation.md << 'EOF'
# Exercise 3: Cost Allocation and Chargeback

## Objective
Implement cost allocation tags and create chargeback reports for different departments.

## Prerequisites
- Cost allocation tags enabled
- AWS Cost Explorer access
- Cost categories created

## Duration
30 minutes

## Tasks

### Task 1: Review Cost Categories
```bash
# List cost categories
aws ce list-cost-category-definitions

# Get specific category details
aws ce describe-cost-category-definition \
  --cost-category-arn $(terraform output -raw cost_category_arn)
```

### Task 2: Generate Department Cost Report
```bash
# Get costs by department
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=COST_CATEGORY,Key=Departments
```

### Task 3: Create Cost Allocation Report
1. Enable cost allocation tags in Billing console
2. Generate CSV report
3. Analyze departmental spending

## Validation
- Cost categories are properly defined
- Reports show departmental breakdown
- Tags are being applied to resources

## Key Takeaways
- Cost allocation enables chargeback models
- Tags are essential for cost tracking
- Regular monitoring prevents budget overruns
EOF

echo -e "${GREEN}✓${NC} Domain 1 exercises created"

# Domain 2 Exercises
echo -e "\n${YELLOW}Creating Domain 2 exercises...${NC}"

cat > domains/domain2-new-solutions/exercises/01-microservices-deployment.md << 'EOF'
# Exercise 1: Microservices Deployment

## Objective
Deploy a microservices architecture using API Gateway and Lambda functions.

## Prerequisites
- Domain 2 infrastructure deployed
- Lambda functions ready
- API Gateway configured

## Duration
45 minutes

## Tasks

### Task 1: Deploy Lambda Function
```bash
# Create deployment package
cd lambda
zip function.zip index.py
aws lambda update-function-code \
  --function-name $(terraform output -raw lambda_function_name) \
  --zip-file fileb://function.zip
```

### Task 2: Configure API Gateway
1. Create REST API resources
2. Configure Lambda integration
3. Deploy API stage

```bash
# Get API Gateway ID
API_ID=$(terraform output -raw api_gateway_id)

# Create resource
aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $(aws apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text) \
  --path-part "users"
```

### Task 3: Test Microservice
```bash
# Get invoke URL
INVOKE_URL=$(aws apigateway get-stages \
  --rest-api-id $API_ID \
  --query 'item[0].invokeUrl' \
  --output text)

# Test endpoint
curl -X GET $INVOKE_URL/users
```

## Validation
- Lambda function executes successfully
- API Gateway returns proper responses
- CloudWatch logs show execution details
EOF

cat > domains/domain2-new-solutions/exercises/02-auto-scaling-strategies.md << 'EOF'
# Exercise 2: Auto Scaling Strategies

## Objective
Implement and test different auto scaling strategies including target tracking and predictive scaling.

## Prerequisites
- Auto Scaling Group deployed
- CloudWatch metrics available
- Load testing tool ready

## Duration
60 minutes

## Tasks

### Task 1: Configure Target Tracking
```bash
# Get ASG name
ASG_NAME=$(terraform output -raw autoscaling_group_name)

# View current scaling policies
aws autoscaling describe-policies --auto-scaling-group-name $ASG_NAME
```

### Task 2: Generate Load
```bash
# Install stress testing tool
sudo yum install -y stress

# Generate CPU load
stress --cpu 2 --timeout 300s
```

### Task 3: Monitor Scaling Behavior
1. Watch CloudWatch metrics
2. Observe instance launches
3. Verify target tracking

```bash
# Monitor ASG activity
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query "AutoScalingGroups[0].[DesiredCapacity,Instances[].InstanceId]"'
```

## Validation
- Auto Scaling responds to load
- New instances launch automatically
- Scaling policies work as expected
EOF

cat > domains/domain2-new-solutions/exercises/03-global-content-delivery.md << 'EOF'
# Exercise 3: Global Content Delivery

## Objective
Implement CloudFront distribution for global content delivery with caching strategies.

## Prerequisites
- S3 bucket with static content
- CloudFront distribution created
- Sample content uploaded

## Duration
30 minutes

## Tasks

### Task 1: Upload Content to S3
```bash
# Create sample content
echo "<html><body><h1>Hello from CloudFront!</h1></body></html>" > index.html

# Upload to S3
aws s3 cp index.html s3://$(terraform output -raw s3_bucket_name)/

# Set bucket policy for CloudFront
aws s3api put-bucket-policy --bucket $(terraform output -raw s3_bucket_name) \
  --policy file://bucket-policy.json
```

### Task 2: Configure CloudFront Behaviors
1. Set cache behaviors
2. Configure TTL values
3. Enable compression

### Task 3: Test Global Distribution
```bash
# Get CloudFront domain
CF_DOMAIN=$(terraform output -raw cloudfront_domain)

# Test from different locations
curl -I https://$CF_DOMAIN/index.html

# Check cache headers
curl -I https://$CF_DOMAIN/index.html | grep -i cache
```

## Validation
- Content serves from CloudFront
- Cache headers are correct
- Global edge locations serve content
EOF

echo -e "${GREEN}✓${NC} Domain 2 exercises created"

# Domain 3 Exercises
echo -e "\n${YELLOW}Creating Domain 3 exercises...${NC}"

cat > domains/domain3-continuous-improvement/exercises/01-security-monitoring.md << 'EOF'
# Exercise 1: Security Monitoring Setup

## Objective
Implement comprehensive security monitoring using Security Hub, GuardDuty, and Config.

## Prerequisites
- Domain 3 infrastructure deployed
- Security services enabled
- Appropriate IAM permissions

## Duration
45 minutes

## Tasks

### Task 1: Enable Security Hub
```bash
# Enable Security Hub
aws securityhub enable-security-hub

# Enable security standards
aws securityhub batch-enable-standards \
  --standards-arn "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.2.0"
```

### Task 2: Configure GuardDuty
```bash
# Enable GuardDuty
aws guardduty create-detector --enable

# List findings
aws guardduty list-findings --detector-id $(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
```

### Task 3: Create Custom Config Rules
1. Define compliance rules
2. Enable automatic remediation
3. Test rule evaluation

## Validation
- Security Hub dashboard shows findings
- GuardDuty is actively monitoring
- Config rules evaluate resources
EOF

cat > domains/domain3-continuous-improvement/exercises/02-cost-optimization.md << 'EOF'
# Exercise 2: Cost Optimization Analysis

## Objective
Identify and implement cost optimization opportunities across your infrastructure.

## Prerequisites
- Cost Explorer access
- Trusted Advisor enabled
- CloudWatch metrics

## Duration
30 minutes

## Tasks

### Task 1: Analyze Current Costs
```bash
# Get cost breakdown by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE
```

### Task 2: Identify Optimization Opportunities
1. Review Trusted Advisor recommendations
2. Check for idle resources
3. Analyze reserved instance coverage

### Task 3: Implement Optimizations
```bash
# Find idle EBS volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].{ID:VolumeId,Size:Size,Type:VolumeType}'

# Check for unattached EIPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].{IP:PublicIp,AllocationId:AllocationId}'
```

## Validation
- Cost reduction opportunities identified
- Idle resources cleaned up
- Savings tracked in Cost Explorer
EOF

echo -e "${GREEN}✓${NC} Domain 3 exercises created"

# Domain 4 Exercises
echo -e "\n${YELLOW}Creating Domain 4 exercises...${NC}"

cat > domains/domain4-migration-modernization/exercises/01-database-migration.md << 'EOF'
# Exercise 1: Database Migration with DMS

## Objective
Migrate a database from on-premises to AWS using Database Migration Service.

## Prerequisites
- DMS replication instance deployed
- Source and target databases ready
- Network connectivity established

## Duration
60 minutes

## Tasks

### Task 1: Configure DMS Endpoints
```bash
# Create source endpoint
aws dms create-endpoint \
  --endpoint-identifier source-mysql \
  --endpoint-type source \
  --engine-name mysql \
  --server-name source.example.com \
  --port 3306 \
  --username admin \
  --password password

# Create target endpoint
aws dms create-endpoint \
  --endpoint-identifier target-aurora \
  --endpoint-type target \
  --engine-name aurora \
  --server-name $(terraform output -raw aurora_endpoint) \
  --port 3306 \
  --username admin \
  --password password
```

### Task 2: Create Migration Task
1. Define table mappings
2. Configure migration type
3. Start migration task

### Task 3: Monitor Migration Progress
```bash
# Check task status
aws dms describe-replication-tasks \
  --query 'ReplicationTasks[].{Status:Status,Progress:ReplicationTaskStats}'
```

## Validation
- Data successfully migrated
- Target database contains all data
- Applications can connect to new database
EOF

cat > domains/domain4-migration-modernization/exercises/02-containerization.md << 'EOF'
# Exercise 2: Application Containerization

## Objective
Containerize a legacy application and deploy it to ECS Fargate.

## Prerequisites
- ECS cluster created
- Container registry available
- Sample application ready

## Duration
45 minutes

## Tasks

### Task 1: Create Dockerfile
```dockerfile
FROM node:14-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### Task 2: Build and Push Image
```bash
# Build Docker image
docker build -t my-app:latest .

# Tag for ECR
docker tag my-app:latest $(aws ecr get-login-password --region us-east-1).dkr.ecr.us-east-1.amazonaws.com/my-app:latest

# Push to ECR
docker push $(aws ecr get-login-password --region us-east-1).dkr.ecr.us-east-1.amazonaws.com/my-app:latest
```

### Task 3: Deploy to ECS
```bash
# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create service
aws ecs create-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service-name my-app \
  --task-definition my-app:1 \
  --desired-count 2 \
  --launch-type FARGATE
```

## Validation
- Container runs successfully
- Service is healthy in ECS
- Application accessible via load balancer
EOF

echo -e "${GREEN}✓${NC} Domain 4 exercises created"

# Create scenarios directories content
echo -e "\n${YELLOW}Creating scenario descriptions...${NC}"

cat > domains/domain1-organizational-complexity/scenarios/README.md << 'EOF'
# Domain 1 Scenarios

## Multi-Account Governance
- Implement AWS Organizations with multiple OUs
- Deploy Service Control Policies for compliance
- Set up cross-account access patterns

## Network Connectivity
- Configure Transit Gateway for hub-and-spoke
- Implement VPC peering across accounts
- Set up Direct Connect virtual interfaces

## Centralized Logging
- Aggregate logs from multiple accounts
- Implement cross-account CloudTrail
- Set up centralized log analysis

## Cost Management
- Implement chargeback model
- Create cost allocation tags
- Set up budget alerts per department
EOF

cat > domains/domain2-new-solutions/scenarios/README.md << 'EOF'
# Domain 2 Scenarios

## Microservices Architecture
- API Gateway with Lambda backends
- Service mesh implementation
- Event-driven architecture with EventBridge

## Global Resilience
- Multi-region active-active setup
- Global database with Aurora Global
- Cross-region replication strategies

## Performance Optimization
- CloudFront with custom origins
- ElastiCache implementation
- Auto Scaling with predictive scaling

## Security Implementation
- WAF rules for application protection
- API throttling and rate limiting
- Certificate management
EOF

cat > domains/domain3-continuous-improvement/scenarios/README.md << 'EOF'
# Domain 3 Scenarios

## Security Posture
- Security Hub compliance monitoring
- GuardDuty threat detection
- Automated remediation workflows

## Operational Excellence
- Systems Manager automation
- Patch management strategies
- Configuration management

## Cost Optimization
- Reserved Instance planning
- Spot Instance strategies
- Resource right-sizing

## Performance Monitoring
- Custom CloudWatch dashboards
- Application performance monitoring
- Database performance insights
EOF

cat > domains/domain4-migration-modernization/scenarios/README.md << 'EOF'
# Domain 4 Scenarios

## Database Migration
- MySQL to Aurora migration
- Oracle to PostgreSQL migration
- NoSQL migration strategies

## Application Modernization
- Monolith to microservices
- Containerization with ECS/EKS
- Serverless transformation

## Data Modernization
- Data lake implementation
- ETL with AWS Glue
- Analytics with Athena

## Hybrid Architecture
- AWS Outposts integration
- Storage Gateway implementation
- Direct Connect setup
EOF

echo -e "${GREEN}✓${NC} Scenario descriptions created"

# Create outputs documentation
echo -e "\n${YELLOW}Creating outputs documentation...${NC}"

for domain in domain1-organizational-complexity domain2-new-solutions domain3-continuous-improvement domain4-migration-modernization; do
    cat > domains/$domain/outputs/README.md << EOF
# Domain Outputs

After deploying this domain, you can access the following outputs:

\`\`\`bash
# List all outputs
terraform output

# Get specific output value
terraform output -raw <output_name>
\`\`\`

## Available Outputs
Check the outputs.tf file in the domain directory for all available outputs.

## Using Outputs in Exercises
Many exercises reference these outputs. For example:
- Resource IDs for AWS CLI commands
- Endpoints for testing
- ARNs for cross-service integration
EOF
done

echo -e "${GREEN}✓${NC} Outputs documentation created"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Exercises and Scenarios Populated!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}What was created:${NC}"
echo "• 3 exercises for each domain (12 total)"
echo "• Scenario descriptions for each domain"
echo "• Outputs documentation"
echo ""
echo -e "${YELLOW}Directory structure now contains:${NC}"
echo "📁 domains/"
echo "   └── domain1-organizational-complexity/"
echo "       ├── exercises/"
echo "       │   ├── 01-multi-account-setup.md"
echo "       │   ├── 02-transit-gateway-lab.md"
echo "       │   └── 03-cost-allocation.md"
echo "       ├── scenarios/"
echo "       │   └── README.md"
echo "       └── outputs/"
echo "           └── README.md"
echo ""
echo -e "${BLUE}To start learning:${NC}"
echo "1. Deploy the infrastructure first"
echo "2. Navigate to the exercises directory"
echo "3. Follow the step-by-step guides"
echo ""
echo "Example:"
echo "${GREEN}cd domains/domain1-organizational-complexity/exercises/${NC}"
echo "${GREEN}cat 01-multi-account-setup.md${NC}"