#!/bin/bash
# security-status.sh - Check security service status and configurations

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_security_overview() {
    print_status "Getting security infrastructure overview..."
    
    echo ""
    print_success "Security Services Status:"
    terraform output -json security_kms_key 2>/dev/null | jq -r 'if . == "Not deployed" then "❌ KMS Key: Not deployed" else "✅ KMS Key: \(.)" end' || echo "❌ KMS Key: Check deployment"
    
    terraform output -json guardduty_detector 2>/dev/null | jq -r 'if . == {} then "❌ GuardDuty: Not deployed" else "✅ GuardDuty: Enabled" end' || echo "❌ GuardDuty: Check deployment"
    
    terraform output -json config_recorder 2>/dev/null | jq -r 'if . == {} then "❌ AWS Config: Not deployed" else "✅ AWS Config: \(.recorder_name)" end' || echo "❌ AWS Config: Check deployment"
    
    terraform output -json cloudtrail_details 2>/dev/null | jq -r 'if . == {} then "❌ CloudTrail: Not deployed" else "✅ CloudTrail: Enabled" end' || echo "❌ CloudTrail: Check deployment"
}

show_certificate_status() {
    print_status "Checking SSL/TLS certificate status..."
    
    echo ""
    print_success "Certificate Information:"
    terraform output -json acm_certificate 2>/dev/null | jq -r 'if . == {} then "❌ ACM Certificate: Not deployed" else "✅ Certificate: \(.domain_name) (\(.status))" end' || echo "❌ Certificate: Check deployment"
    
    terraform output -json route53_zone 2>/dev/null | jq -r 'if . == {} then "❌ Route 53 Zone: Not created" else "✅ DNS Zone: \(.zone_id)" end' || echo "❌ Route 53: Not deployed"
}

show_iam_status() {
    print_status "Checking IAM configuration..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "IAM Account Settings:"
        
        # Check password policy
        if aws iam get-account-password-policy &>/dev/null; then
            echo "✅ Password Policy: Configured"
        else
            echo "❌ Password Policy: Not configured"
        fi
        
        # List custom roles
        echo ""
        print_success "Custom IAM Roles:"
        aws iam list-roles --query 'Roles[?contains(RoleName, `aws-cert-lab`)].RoleName' --output table 2>/dev/null || echo "No custom roles found"
    else
        echo "AWS CLI not available for IAM checks"
    fi
}

show_systems_manager() {
    print_status "Checking Systems Manager parameters..."
    
    echo ""
    print_success "SSM Parameters:"
    terraform output -json systems_manager_parameters 2>/dev/null | jq -r 'if . == {} then "❌ SSM Parameters: Not deployed" else "✅ Parameters: \(keys | join(", "))" end' || echo "❌ SSM: Check deployment"
    
    if command -v aws &> /dev/null; then
        echo ""
        print_warning "Parameter Details:"
        aws ssm describe-parameters --parameter-filters "Key=Name,Option=BeginsWith,Values=/aws-cert-lab" --query 'Parameters[].{Name:Name,Type:Type,LastModified:LastModifiedDate}' --output table 2>/dev/null || echo "No parameters found"
    fi
}

show_guardduty_findings() {
    print_status "Checking GuardDuty findings..."
    
    if command -v aws &> /dev/null; then
        local detector_id=$(terraform output -json guardduty_detector 2>/dev/null | jq -r '.detector_id // empty')
        
        if [[ -n "$detector_id" ]]; then
            echo ""
            print_success "GuardDuty Findings (Last 7 days):"
            aws guardduty list-findings --detector-id "$detector_id" --finding-criteria '{"updatedAt":{"gte":'"$(($(date +%s) - 604800))"'000}}' --query 'FindingIds' --output table 2>/dev/null || echo "No recent findings or insufficient permissions"
        else
            echo "❌ GuardDuty detector not found"
        fi
    else
        echo "AWS CLI not available for GuardDuty checks"
    fi
}

check_compliance() {
    print_status "Running basic compliance checks..."
    
    echo ""
    print_success "Compliance Status:"
    
    # Check encryption
    if terraform output -json security_kms_key 2>/dev/null | grep -q "arn:aws:kms"; then
        echo "✅ Encryption: KMS keys configured"
    else
        echo "❌ Encryption: No KMS keys found"
    fi
    
    # Check logging
    if terraform output -json cloudtrail_details 2>/dev/null | jq -e '. != {}' >/dev/null; then
        echo "✅ Audit Logging: CloudTrail enabled"
    else
        echo "❌ Audit Logging: CloudTrail not configured"
    fi
    
    # Check monitoring
    if terraform output -json guardduty_detector 2>/dev/null | jq -e '. != {}' >/dev/null; then
        echo "✅ Threat Detection: GuardDuty enabled"
    else
        echo "❌ Threat Detection: GuardDuty not configured"
    fi
}

case ${1:-""} in
    "overview"|"status"|"")
        show_security_overview
        ;;
    "certificates"|"cert"|"ssl")
        show_certificate_status
        ;;
    "iam"|"roles")
        show_iam_status
        ;;
    "ssm"|"parameters")
        show_systems_manager
        ;;
    "guardduty"|"threats")
        show_guardduty_findings
        ;;
    "compliance"|"audit")
        check_compliance
        ;;
    "all")
        show_security_overview
        echo ""
        show_certificate_status
        echo ""
        show_iam_status
        echo ""
        show_systems_manager
        echo ""
        check_compliance
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/security-status.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  overview, status  Show security services overview"
        echo "  certificates, ssl Show SSL certificate status"
        echo "  iam, roles        Show IAM configuration"
        echo "  ssm, parameters   Show Systems Manager parameters"
        echo "  guardduty, threats Show GuardDuty findings"
        echo "  compliance, audit Basic compliance check"
        echo "  all               Show all security information"
        echo "  help              Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/security-status.sh help' for usage"
        exit 1
        ;;
esac
