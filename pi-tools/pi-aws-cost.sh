#!/bin/bash

# Pi-optimized AWS cost monitoring (reduced API calls)

echo "💰 AWS Cost Monitor (Pi Edition)"
echo "================================"

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured"
    exit 1
fi

# Get current month cost (single API call)
START_DATE=$(date -d "$(date +'%Y-%m-01')" +'%Y-%m-%d')
END_DATE=$(date +'%Y-%m-%d')

COST_DATA=$(aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0]' \
    --output json 2>/dev/null)

if [ $? -eq 0 ] && [ "$COST_DATA" != "null" ]; then
    TOTAL_COST=$(echo "$COST_DATA" | jq -r '.Total.BlendedCost.Amount // "0"')
    echo "📊 Current Month Total: \$$(printf "%.2f" $TOTAL_COST)"
    
    # Top services (limit to reduce output on Pi)
    echo ""
    echo "🏷️  Top 5 Services:"
    echo "$COST_DATA" | jq -r '.Groups[] | select(.Total.BlendedCost.Amount > "0.01") | "\(.Keys[0]): $\(.Total.BlendedCost.Amount)"' | sort -rn -k2 -t'$' | head -5
    
    # Cost alert for Pi users
    if (( $(echo "$TOTAL_COST > 50" | bc -l) )); then
        echo ""
        echo "⚠️  Cost Alert: Consider running 'terraform destroy' to save money!"
    fi
else
    echo "❌ Unable to fetch cost data (API limit or permissions issue)"
fi

# Quick resource count (lightweight check)
echo ""
echo "🏗️  Quick Resource Check:"
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`] | length(@)' --output text 2>/dev/null | xargs echo "Running EC2 instances:"
aws rds describe-db-clusters --query 'DBClusters | length(@)' --output text 2>/dev/null | xargs echo "RDS clusters:"
aws elbv2 describe-load-balancers --query 'LoadBalancers | length(@)' --output text 2>/dev/null | xargs echo "Load balancers:"
