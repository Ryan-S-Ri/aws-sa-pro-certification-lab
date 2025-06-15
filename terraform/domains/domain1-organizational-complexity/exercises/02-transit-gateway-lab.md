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
