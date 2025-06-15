#!/bin/bash
# Enhanced cost monitoring for domain-based infrastructure

echo "AWS SA Pro Lab - Cost Monitor"
echo "============================"

# Get cost by domain tags
echo "Cost by Domain:"
aws ce get-cost-and-usage \
    --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --group-by Type=TAG,Key=Domain \
    --filter file://cost-filter.json 2>/dev/null || echo "No cost data available yet"

# Get cost by service
echo -e "\nCost by Service:"
aws ce get-cost-and-usage \
    --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --filter file://cost-filter.json 2>/dev/null || echo "No cost data available yet"

# Estimate monthly cost
echo -e "\nEstimated Monthly Cost:"
echo "Domain 1 (Organizational): ~$50-100/month"
echo "Domain 2 (New Solutions): ~$100-200/month"
echo "Domain 3 (Improvement): ~$75-150/month"
echo "Domain 4 (Migration): ~$100-200/month"
echo "Shared Infrastructure: ~$50-75/month"
echo ""
echo "Total if all domains active: ~$375-725/month"
