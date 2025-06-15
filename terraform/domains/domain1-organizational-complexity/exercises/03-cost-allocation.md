# Exercise 3: Cost Allocation and Chargeback

## Objective
Implement cost allocation tags and create chargeback reports for different departments.

## Prerequisites
- Cost allocation tags enabled
- AWS Cost Explorer access
- Cost categories created

## Duration
30 minutes

## Tasks

### Task 1: Review Cost Categories
```bash
# List cost categories
aws ce list-cost-category-definitions

# Get specific category details
aws ce describe-cost-category-definition \
  --cost-category-arn $(terraform output -raw cost_category_arn)
```

### Task 2: Generate Department Cost Report
```bash
# Get costs by department
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=COST_CATEGORY,Key=Departments
```

### Task 3: Create Cost Allocation Report
1. Enable cost allocation tags in Billing console
2. Generate CSV report
3. Analyze departmental spending

## Validation
- Cost categories are properly defined
- Reports show departmental breakdown
- Tags are being applied to resources

## Key Takeaways
- Cost allocation enables chargeback models
- Tags are essential for cost tracking
- Regular monitoring prevents budget overruns
