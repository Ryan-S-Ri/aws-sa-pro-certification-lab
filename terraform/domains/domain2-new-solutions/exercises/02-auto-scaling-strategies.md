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
