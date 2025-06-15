#!/bin/bash

# Raspberry Pi AWS Lab Dashboard

clear
echo "🥧 Raspberry Pi AWS Lab Dashboard"
echo "================================="
echo ""

# System status
echo "🖥️  Pi System Status:"
echo "===================="

# Temperature
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$((TEMP/1000))
    echo "🌡️  CPU Temperature: ${TEMP_C}°C"
    if [ $TEMP_C -gt 70 ]; then
        echo "⚠️  High temperature detected!"
    fi
fi

# Memory
echo "💾 Memory Usage:"
free -h | head -2

# Disk
echo "💿 Disk Usage:"
df -h / | tail -1

# Load
echo "⚙️  System Load:"
uptime

echo ""
echo "☁️  AWS Lab Status:"
echo "=================="

# AWS connectivity
if aws sts get-caller-identity --query 'Account' --output text &> /dev/null; then
    ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
    REGION=$(aws configure get region)
    echo "✅ AWS Connected - Account: $ACCOUNT, Region: $REGION"
else
    echo "❌ AWS Not Connected"
fi

# Terraform status
if [ -f ~/aws-certification-lab/terraform/terraform.tfstate ]; then
    echo "🏗️  Terraform Status: Infrastructure Deployed"
    
    # Get resource count
    cd ~/aws-certification-lab/terraform
    RESOURCES=$(terraform show -json 2>/dev/null | jq '.values.root_module.resources | length' 2>/dev/null || echo "Unknown")
    echo "   Resources: $RESOURCES"
    
    echo ""
    echo "📊 Current Infrastructure:"
    terraform output 2>/dev/null | head -10
else
    echo "🏗️  Terraform Status: Not deployed"
fi

echo ""
echo "💰 Quick Cost Check:"
echo "==================="

# Simple cost check
START_DATE=$(date -d "$(date +'%Y-%m-01')" +'%Y-%m-%d')
END_DATE=$(date +'%Y-%m-%d')

COST_DATA=$(aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
    --output text 2>/dev/null)

if [ $? -eq 0 ] && [ "$COST_DATA" != "None" ] && [ "$COST_DATA" != "" ]; then
    echo "💵 Current month cost: \$$(printf "%.2f" $COST_DATA)"
    if (( $(echo "$COST_DATA > 50" | bc -l 2>/dev/null || echo 0) )); then
        echo "⚠️  Cost alert: Consider cleanup!"
    fi
else
    echo "💵 Cost data not available (new account or API limit)"
fi

echo ""
echo "🏗️  Quick Resource Count:"
echo "========================"
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`] | length(@)' --output text 2>/dev/null | sed 's/^/EC2 instances: /'
aws s3 ls 2>/dev/null | wc -l | sed 's/^/S3 buckets: /'
aws rds describe-db-clusters --query 'DBClusters | length(@)' --output text 2>/dev/null | sed 's/^/RDS clusters: /'

echo ""
echo "💡 Quick Commands:"
echo "=================="
echo "   pi-cost     - Detailed cost monitoring"
echo "   pi-status   - Pi system status only"
echo "   lab         - Go to lab directory"
echo "   tf          - Go to terraform directory"
echo ""
echo "🚀 Terraform Commands:"
echo "   cd ~/aws-certification-lab/terraform"
echo "   ./scripts/setup.sh    - Deploy more infrastructure"
echo "   terraform destroy     - Clean up resources"
echo ""
echo "📊 Monitoring:"
echo "   watch -n 30 pi-dash   - Auto-refresh dashboard"
echo "   vcgencmd measure_temp  - Pi temperature"
