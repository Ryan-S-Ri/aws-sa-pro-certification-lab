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
