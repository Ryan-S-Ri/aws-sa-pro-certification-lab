#!/bin/bash
# security-audit.sh - Perform security audit and recommendations

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "🔍 Security Audit Report"
echo "======================="
echo ""

audit_score=0
total_checks=0

check_item() {
    local name="$1"
    local command="$2"
    local success_msg="$3"
    local fail_msg="$4"
    
    ((total_checks++))
    print_status "Checking: $name..."
    
    if eval "$command" &>/dev/null; then
        print_success "$success_msg"
        ((audit_score++))
    else
        print_error "$fail_msg"
    fi
}

# Security service checks
print_status "=== SECURITY SERVICES ==="
check_item "KMS Encryption" \
    'terraform output -json security_kms_key | grep -q "arn:aws:kms"' \
    "KMS encryption keys are configured" \
    "KMS encryption keys are missing"

check_item "GuardDuty Detection" \
    'terraform output -json guardduty_detector | jq -e ".detector_id" >/dev/null' \
    "GuardDuty threat detection is enabled" \
    "GuardDuty is not configured"

check_item "CloudTrail Logging" \
    'terraform output -json cloudtrail_details | jq -e ".trail_arn" >/dev/null' \
    "CloudTrail audit logging is enabled" \
    "CloudTrail is not configured"

check_item "AWS Config Compliance" \
    'terraform output -json config_recorder | jq -e ".recorder_name" >/dev/null' \
    "AWS Config compliance monitoring is enabled" \
    "AWS Config is not configured"

echo ""
print_status "=== IAM SECURITY ==="
check_item "Password Policy" \
    'aws iam get-account-password-policy' \
    "IAM password policy is configured" \
    "IAM password policy is missing"

check_item "Custom Security Roles" \
    'terraform output -json security_iam_roles | jq -e ".security_auditor" >/dev/null' \
    "Custom security roles are configured" \
    "Custom security roles are missing"

echo ""
print_status "=== DATA PROTECTION ==="
check_item "Systems Manager Parameters" \
    'terraform output -json systems_manager_parameters | jq -e ".db_password" >/dev/null' \
    "Secrets are stored in Systems Manager" \
    "Systems Manager parameters are missing"

check_item "S3 Bucket Encryption" \
    'aws s3api get-bucket-encryption --bucket $(terraform output -raw lab_bucket_name) 2>/dev/null' \
    "S3 buckets have encryption enabled" \
    "S3 bucket encryption may be missing"

echo ""
print_status "=== NETWORK SECURITY ==="
check_item "VPC Flow Logs" \
    'terraform output -json monitoring_log_groups | jq -e ".vpc_flow_logs" >/dev/null' \
    "VPC Flow Logs are enabled for network monitoring" \
    "VPC Flow Logs are not configured"

# Calculate security score
echo ""
print_status "=== SECURITY SCORE ==="
percentage=$((audit_score * 100 / total_checks))

if [[ $percentage -ge 90 ]]; then
    print_success "Security Score: $audit_score/$total_checks ($percentage%) - EXCELLENT"
elif [[ $percentage -ge 75 ]]; then
    print_success "Security Score: $audit_score/$total_checks ($percentage%) - GOOD"
elif [[ $percentage -ge 60 ]]; then
    print_warning "Security Score: $audit_score/$total_checks ($percentage%) - NEEDS IMPROVEMENT"
else
    print_error "Security Score: $audit_score/$total_checks ($percentage%) - CRITICAL ISSUES"
fi

echo ""
print_status "=== RECOMMENDATIONS ==="
if [[ $audit_score -lt $total_checks ]]; then
    echo "🔧 To improve your security posture:"
    echo "   1. Deploy missing security services"
    echo "   2. Enable all monitoring and logging"
    echo "   3. Review IAM policies and roles"
    echo "   4. Ensure all data is encrypted"
    echo "   5. Run: ./study-deploy.sh domain1 (for security focus)"
fi

echo ""
print_status "=== COST ESTIMATE ==="
print_warning "Security services estimated cost:"
echo "   • GuardDuty: ~$3-5/month"
echo "   • AWS Config: ~$2-4/month"
echo "   • CloudTrail: ~$1-3/month"
echo "   • KMS: ~$1/month"
echo "   • Systems Manager: Free tier"
echo "   • Total: ~$7-13/month"
