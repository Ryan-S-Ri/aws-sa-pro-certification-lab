#!/bin/bash
# monitoring-dashboard.sh - Helper script for monitoring dashboards and metrics

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

show_dashboards() {
    print_status "Getting CloudWatch dashboard URLs..."
    
    echo ""
    print_success "Dashboard URLs:"
    terraform output -json cloudwatch_dashboards 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
    
    echo ""
    print_success "SNS Topics:"
    terraform output -json monitoring_sns_topics 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
}

show_alarms() {
    print_status "Checking CloudWatch alarms..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "Current Alarm States:"
        aws cloudwatch describe-alarms --query 'MetricAlarms[?contains(AlarmName, `aws-cert-lab`)].{Name:AlarmName,State:StateValue,Reason:StateReason}' --output table 2>/dev/null || echo "AWS CLI not configured or no alarms found"
    else
        echo "AWS CLI not installed"
    fi
}

show_logs() {
    print_status "CloudWatch log groups..."
    
    echo ""
    print_success "Log Groups:"
    terraform output -json monitoring_log_groups 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
    
    if command -v aws &> /dev/null; then
        echo ""
        print_warning "Recent log streams:"
        aws logs describe-log-groups --log-group-name-prefix "/aws/application/aws-cert-lab" --query 'logGroups[].logGroupName' --output table 2>/dev/null || echo "No log groups found"
    fi
}

show_budget() {
    print_status "Checking AWS Budget..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "Budget Information:"
        aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text) --query 'Budgets[?contains(BudgetName, `aws-cert-lab`)].{Name:BudgetName,Limit:BudgetLimit.Amount,Unit:BudgetLimit.Unit}' --output table 2>/dev/null || echo "No budgets found or insufficient permissions"
    else
        echo "AWS CLI not installed"
    fi
}

test_alerts() {
    print_status "Testing SNS alert delivery..."
    
    local topic_arn=$(terraform output -json monitoring_sns_topics 2>/dev/null | jq -r '.alerts' 2>/dev/null)
    
    if [[ "$topic_arn" != "null" && "$topic_arn" != "" ]]; then
        if command -v aws &> /dev/null; then
            aws sns publish --topic-arn "$topic_arn" --message "Test alert from monitoring system - $(date)" --subject "Test Alert" 2>/dev/null && echo "Test alert sent!" || echo "Failed to send test alert"
        else
            echo "AWS CLI not available for testing"
        fi
    else
        echo "No SNS topic found - run terraform apply first"
    fi
}

case ${1:-""} in
    "dashboards"|"dash"|"")
        show_dashboards
        ;;
    "alarms"|"alarm")
        show_alarms
        ;;
    "logs"|"log")
        show_logs
        ;;
    "budget"|"cost")
        show_budget
        ;;
    "test"|"test-alert")
        test_alerts
        ;;
    "all")
        show_dashboards
        echo ""
        show_alarms
        echo ""
        show_logs
        echo ""
        show_budget
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/monitoring-dashboard.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  dashboards, dash  Show CloudWatch dashboard URLs"
        echo "  alarms, alarm     Show current alarm states"
        echo "  logs, log         Show log groups and streams"
        echo "  budget, cost      Show budget information"
        echo "  test, test-alert  Send test SNS alert"
        echo "  all               Show all monitoring information"
        echo "  help              Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/monitoring-dashboard.sh help' for usage"
        exit 1
        ;;
esac
