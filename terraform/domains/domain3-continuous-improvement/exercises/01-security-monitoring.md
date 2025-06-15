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
