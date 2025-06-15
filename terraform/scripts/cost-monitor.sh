#!/bin/bash
# cost-monitor.sh - Helper script for cost monitoring and analysis

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

show_current_costs() {
    print_status "Getting current AWS costs..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "Current Month Costs by Service:"
        
        local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
        local end_date=$(date +%Y-%m-%d)
        
        aws ce get-cost-and-usage \
            --time-period Start=$start_date,End=$end_date \
            --granularity MONTHLY \
            --metrics "BlendedCost" \
            --group-by Type=DIMENSION,Key=SERVICE \
            --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`0.01`].{Service:Keys[0],Cost:Metrics.BlendedCost.Amount,Unit:Metrics.BlendedCost.Unit}' \
            --output table 2>/dev/null || echo "Cost Explorer API not available or insufficient permissions"
    else
        echo "AWS CLI not installed"
    fi
}

show_daily_costs() {
    print_status "Getting daily cost breakdown..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "Last 7 Days Daily Costs:"
        
        local start_date=$(date -d "7 days ago" +%Y-%m-%d)
        local end_date=$(date +%Y-%m-%d)
        
        aws ce get-cost-and-usage \
            --time-period Start=$start_date,End=$end_date \
            --granularity DAILY \
            --metrics "BlendedCost" \
            --query 'ResultsByTime[].{Date:TimePeriod.Start,Cost:Total.BlendedCost.Amount,Unit:Total.BlendedCost.Unit}' \
            --output table 2>/dev/null || echo "Cost Explorer API not available"
    else
        echo "AWS CLI not installed"
    fi
}

show_budget_status() {
    print_status "Checking budget status..."
    
    if command -v aws &> /dev/null; then
        echo ""
        print_success "Budget Status:"
        
        local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        if [[ -n "$account_id" ]]; then
            aws budgets describe-budgets --account-id $account_id \
                --query 'Budgets[?contains(BudgetName, `aws-cert-lab`)].{Name:BudgetName,Limit:BudgetLimit.Amount,Actual:CalculatedSpend.ActualSpend.Amount,Forecasted:CalculatedSpend.ForecastedSpend.Amount}' \
                --output table 2>/dev/null || echo "No budgets found or insufficient permissions"
        else
            echo "Unable to get account ID"
        fi
    else
        echo "AWS CLI not installed"
    fi
}

estimate_monthly_cost() {
    print_status "Estimating monthly cost based on current infrastructure..."
    
    echo ""
    print_warning "Estimated Monthly Costs (based on current deployment):"
    
    # Get current resource counts
    local compute_enabled=$(terraform output -json auto_scaling_group_names 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    local database_enabled=$(terraform output -json database_endpoints 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    local monitoring_enabled=$(terraform output -json monitoring_sns_topics 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    
    local total_estimate=0
    
    if [[ "$compute_enabled" -gt 0 ]]; then
        echo "  💻 Compute Tier: ~$8-15/month (t3.micro instances, ALB)"
        total_estimate=$((total_estimate + 12))
    fi
    
    if [[ "$database_enabled" -gt 0 ]]; then
        echo "  🗃️  Database Tier: ~$15-30/month (Aurora t3.micro, DynamoDB, ElastiCache)"
        total_estimate=$((total_estimate + 22))
    fi
    
    if [[ "$monitoring_enabled" -gt 0 ]]; then
        echo "  📊 Monitoring Tier: ~$2-8/month (CloudWatch, SNS, Budgets)"
        total_estimate=$((total_estimate + 5))
    fi
    
    echo "  🌐 Networking: ~$3-10/month (VPC, NAT Gateway if enabled)"
    total_estimate=$((total_estimate + 6))
    
    echo ""
    print_warning "Estimated Total: ~${total_estimate}/month"
    echo ""
    print_error "⚠️  Always destroy resources after study sessions to minimize costs!"
}

set_budget_alert() {
    local limit=${1:-50}
    print_status "Setting budget alert for \$limit/month..."
    
    if command -v aws &> /dev/null; then
        # This would require AWS CLI budget creation
        echo "Budget configuration should be done through Terraform"
        echo "Update monthly_budget_limit variable in your .tfvars file"
    else
        echo "AWS CLI not installed"
    fi
}

case ${1:-""} in
    "current"|"now"|"")
        show_current_costs
        ;;
    "daily"|"day")
        show_daily_costs
        ;;
    "budget"|"budgets")
        show_budget_status
        ;;
    "estimate"|"est")
        estimate_monthly_cost
        ;;
    "alert")
        set_budget_alert $2
        ;;
    "all")
        show_current_costs
        echo ""
        show_daily_costs
        echo ""
        show_budget_status
        echo ""
        estimate_monthly_cost
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/cost-monitor.sh [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  current, now      Show current month costs by service"
        echo "  daily, day        Show daily costs for last 7 days"
        echo "  budget, budgets   Show budget status"
        echo "  estimate, est     Estimate monthly costs based on current deployment"
        echo "  alert [amount]    Set budget alert (amount in USD)"
        echo "  all               Show all cost information"
        echo "  help              Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./scripts/cost-monitor.sh current"
        echo "  ./scripts/cost-monitor.sh alert 30"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/cost-monitor.sh help' for usage"
        exit 1
        ;;
esac
