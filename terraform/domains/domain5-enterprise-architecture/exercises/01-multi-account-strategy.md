# Exercise 1: Multi-Account Strategy Implementation

## Objective
Design and implement a multi-account strategy using AWS Organizations and Service Control Policies.

## Scenario
Your organization is expanding and needs to implement proper governance across multiple AWS accounts for different business units while maintaining security and compliance.

## Tasks

### 1. AWS Organizations Setup
```bash
# Deploy the enterprise architecture domain
terraform apply -var-file="study-configs/sa-pro-enterprise.tfvars"
```

### 2. Service Control Policy Implementation
- Review the implemented SCP that restricts dangerous actions
- Understand how SCPs work with IAM permissions
- Test the policy restrictions

### 3. Cross-Account Role Configuration
- Set up cross-account access roles
- Configure external ID for additional security
- Test role assumption from different accounts

### 4. Governance Implementation
- Configure AWS Config aggregator
- Set up Security Hub for centralized security findings
- Implement GuardDuty across accounts

## Key Learning Points
- AWS Organizations hierarchy and OUs
- Service Control Policies vs IAM policies
- Cross-account access patterns
- Centralized security monitoring
- Enterprise governance strategies

## Validation
1. Verify SCP prevents deletion of CloudTrail
2. Test cross-account role assumption
3. Check Config aggregator collects data
4. Confirm Security Hub shows findings

## Cleanup
```bash
terraform destroy -var-file="study-configs/sa-pro-enterprise.tfvars"
```
