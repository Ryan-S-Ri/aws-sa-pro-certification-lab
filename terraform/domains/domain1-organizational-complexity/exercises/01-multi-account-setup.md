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
