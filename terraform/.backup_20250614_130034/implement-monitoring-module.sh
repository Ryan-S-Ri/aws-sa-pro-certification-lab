#!/bin/bash
# implement-monitoring-module-fixed.sh - Corrected monitoring module implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}[SETUP]${NC} $1"; }

echo "📊 AWS Certification Lab - Monitoring Module (CORRECTED VERSION)"
echo "=================================================================="
echo ""

# Check prerequisites
print_status "Checking prerequisites..."
if [[ ! -f "main.tf" || ! -f "variables.tf" ]]; then
    print_error "Please run this script from your Terraform project root directory"
    exit 1
fi

print_success "✅ Prerequisites met"

# Step 1: Add ALL monitoring variables first
print_header "Adding complete monitoring variables to variables.tf..."
cat >> variables.tf << 'EOF'

# ================================================================
# MONITORING & OBSERVABILITY VARIABLES - COMPLETE SET
# ================================================================

# Core monitoring toggles
variable "enable_cost_monitoring" {
  description = "Enable cost monitoring and budgets"
  type        = bool
  default     = true
}

variable "enable_security_monitoring" {
  description = "Enable security-focused monitoring"
  type        = bool
  default     = true
}

variable "enable_eventbridge" {
  description = "Enable EventBridge rules and targets"
  type        = bool
  default     = true
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_lambda_monitoring" {
  description = "Enable Lambda function monitoring"
  type        = bool
  default     = false
}

# Cost monitoring settings
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "50"
  
  validation {
    condition     = can(tonumber(var.monthly_budget_limit)) && tonumber(var.monthly_budget_limit) > 0
    error_message = "Monthly budget limit must be a positive number."
  }
}

# Alert thresholds
variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_alarm_threshold > 0 && var.cpu_alarm_threshold <= 100
    error_message = "CPU alarm threshold must be between 1 and 100."
  }
}

variable "rds_connection_threshold" {
  description = "RDS connection count threshold for alarms"
  type        = number
  default     = 80
  
  validation {
    condition     = var.rds_connection_threshold > 0
    error_message = "RDS connection threshold must be greater than 0."
  }
}

# Additional monitoring features
variable "enable_cloudwatch_insights" {
  description = "Enable CloudWatch Insights for log analysis"
  type        = bool
  default     = true
}

variable "enable_custom_metrics" {
  description = "Enable custom application metrics"
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "Enable Container Insights (for ECS/EKS when available)"
  type        = bool
  default     = false
}

variable "enable_application_insights" {
  description = "Enable CloudWatch Application Insights"
  type        = bool
  default     = false
}

variable "enable_synthetics" {
  description = "Enable CloudWatch Synthetics for website monitoring"
  type        = bool
  default     = false
}
EOF

print_success "✅ All monitoring variables added"

# Step 2: Create corrected monitoring.tf
print_header "Creating corrected monitoring.tf..."
cat > monitoring.tf << 'EOF'
# monitoring.tf - Monitoring & Observability Infrastructure (CORRECTED)

# ================================================================
# KMS KEY FOR MONITORING ENCRYPTION
# ================================================================

resource "aws_kms_key" "monitoring" {
  count                   = var.enable_monitoring_tier ? 1 : 0
  provider                = aws.primary
  description             = "KMS key for monitoring services encryption"
  deletion_window_in_days = var.development_mode ? 7 : 30
  enable_key_rotation     = true

  tags = {
    Name = "${local.common_name}-monitoring-key"
  }
}

resource "aws_kms_alias" "monitoring" {
  count         = var.enable_monitoring_tier ? 1 : 0
  provider      = aws.primary
  name          = "alias/${local.common_name}-monitoring"
  target_key_id = aws_kms_key.monitoring[0].key_id
}

# ================================================================
# SNS TOPICS FOR NOTIFICATIONS
# ================================================================

resource "aws_sns_topic" "alerts" {
  count    = var.enable_monitoring_tier ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-alerts"

  kms_master_key_id = var.enable_kms_advanced ? aws_kms_key.monitoring[0].arn : null

  tags = {
    Name = "${local.common_name}-alerts"
  }
}

resource "aws_sns_topic" "cost_alerts" {
  count    = var.enable_monitoring_tier && var.enable_cost_monitoring ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-cost-alerts"

  kms_master_key_id = var.enable_kms_advanced ? aws_kms_key.monitoring[0].arn : null

  tags = {
    Name = "${local.common_name}-cost-alerts"
  }
}

# ================================================================
# SNS SUBSCRIPTIONS
# ================================================================

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.enable_monitoring_tier ? 1 : 0
  provider  = aws.primary
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "email_cost_alerts" {
  count     = var.enable_monitoring_tier && var.enable_cost_monitoring ? 1 : 0
  provider  = aws.primary
  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ================================================================
# CLOUDWATCH LOG GROUPS
# ================================================================

resource "aws_cloudwatch_log_group" "application" {
  count             = var.enable_monitoring_tier ? 1 : 0
  provider          = aws.primary
  name              = "/aws/application/${local.common_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_kms_advanced ? aws_kms_key.monitoring[0].arn : null

  tags = {
    Name = "${local.common_name}-application-logs"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.enable_monitoring_tier && var.enable_vpc_flow_logs ? 1 : 0
  provider          = aws.primary
  name              = "/aws/vpc/flowlogs/${local.common_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_kms_advanced ? aws_kms_key.monitoring[0].arn : null

  tags = {
    Name = "${local.common_name}-vpc-flow-logs"
  }
}

# ================================================================
# VPC FLOW LOGS
# ================================================================

resource "aws_iam_role" "vpc_flow_logs" {
  count    = var.enable_monitoring_tier && var.enable_vpc_flow_logs ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.common_name}-vpc-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count    = var.enable_monitoring_tier && var.enable_vpc_flow_logs ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-vpc-flow-logs-policy"
  role     = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  count           = var.enable_monitoring_tier && var.enable_vpc_flow_logs ? 1 : 0
  provider        = aws.primary
  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.primary.id

  tags = {
    Name = "${local.common_name}-vpc-flow-logs"
  }
}

# ================================================================
# CLOUDWATCH ALARMS - BASIC SET
# ================================================================

# High CPU alarm for compute tier (when enabled)
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  count               = var.enable_monitoring_tier && var.enable_compute_tier ? 1 : 0
  provider            = aws.primary
  alarm_name          = "${local.common_name}-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "EC2 CPU utilization is high"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]

  tags = {
    Name = "${local.common_name}-ec2-high-cpu-alarm"
  }
}

# RDS CPU alarm (when database tier enabled)
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.enable_monitoring_tier && var.enable_database_tier ? 1 : 0
  provider            = aws.primary
  alarm_name          = "${local.common_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "RDS CPU utilization is high"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]

  tags = {
    Name = "${local.common_name}-rds-cpu-alarm"
  }
}

# ================================================================
# CLOUDWATCH DASHBOARD (NO TAGS - NOT SUPPORTED)
# ================================================================

resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_monitoring_tier ? 1 : 0
  provider       = aws.primary
  dashboard_name = "${local.common_name}-infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization"],
            ["AWS/RDS", "CPUUtilization"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
          title   = "Infrastructure Overview"
          period  = 300
        }
      }
    ]
  })
}

# ================================================================
# AWS BUDGETS
# ================================================================

resource "aws_budgets_budget" "monthly" {
  count        = var.enable_monitoring_tier && var.enable_cost_monitoring ? 1 : 0
  provider     = aws.primary
  name         = "${local.common_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]
  }

  tags = {
    Name = "${local.common_name}-monthly-budget"
  }
}

# ================================================================
# EVENTBRIDGE RULES (BASIC)
# ================================================================

resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  count       = var.enable_monitoring_tier && var.enable_eventbridge ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-ec2-state-change"
  description = "Capture EC2 instance state changes"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["running", "stopped", "terminated"]
    }
  })

  tags = {
    Name = "${local.common_name}-ec2-state-change-rule"
  }
}

resource "aws_cloudwatch_event_target" "ec2_state_change_sns" {
  count     = var.enable_monitoring_tier && var.enable_eventbridge ? 1 : 0
  provider  = aws.primary
  rule      = aws_cloudwatch_event_rule.ec2_state_change[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts[0].arn
}
EOF

print_success "✅ Corrected monitoring.tf created"

# Step 3: Add monitoring outputs to outputs.tf
print_header "Adding monitoring outputs..."
cat >> outputs.tf << 'EOF'

# ================================================================
# MONITORING OUTPUTS
# ================================================================

output "monitoring_sns_topics" {
  description = "SNS topic ARNs for monitoring"
  value = var.enable_monitoring_tier ? {
    alerts      = aws_sns_topic.alerts[0].arn
    cost_alerts = var.enable_cost_monitoring ? aws_sns_topic.cost_alerts[0].arn : "Not deployed"
  } : {}
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value = var.enable_monitoring_tier ? "https://${var.primary_region}.console.aws.amazon.com/cloudwatch/home?region=${var.primary_region}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : "Not deployed"
}

output "monitoring_log_groups" {
  description = "CloudWatch log group names"
  value = var.enable_monitoring_tier ? {
    application   = aws_cloudwatch_log_group.application[0].name
    vpc_flow_logs = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : "Not deployed"
  } : {}
}

output "budget_name" {
  description = "AWS Budget name"
  value = var.enable_monitoring_tier && var.enable_cost_monitoring ? aws_budgets_budget.monthly[0].name : "Not deployed"
}
EOF

print_success "✅ Monitoring outputs added"

# Step 4: Update domain configurations
print_header "Updating study configurations..."

# Update Domain 4
cat >> study-configs/domain4-cost-optimized.tfvars << 'EOF'

# Monitoring configuration for Domain 4
monthly_budget_limit = "30"
cpu_alarm_threshold = 80
rds_connection_threshold = 80
enable_cost_monitoring = true
enable_security_monitoring = true
enable_eventbridge = true
enable_xray = false
enable_lambda_monitoring = false
EOF

# Update Full Lab
cat >> study-configs/full-lab.tfvars << 'EOF'

# Monitoring configuration for Full Lab
monthly_budget_limit = "100"
cpu_alarm_threshold = 70
rds_connection_threshold = 100
enable_cost_monitoring = true
enable_security_monitoring = true
enable_eventbridge = true
enable_xray = true
enable_lambda_monitoring = true
EOF

# Create monitoring-only config
cat > study-configs/monitoring-only.tfvars << 'EOF'
# Monitoring-only configuration
enable_compute_tier = false
enable_database_tier = false
enable_monitoring_tier = true
enable_advanced_networking = false
enable_disaster_recovery = false

# Monitoring settings
monthly_budget_limit = "20"
cpu_alarm_threshold = 80
rds_connection_threshold = 80
enable_cost_monitoring = true
enable_security_monitoring = true
enable_eventbridge = true
enable_xray = false
enable_lambda_monitoring = false

# Basic settings
development_mode = true
log_retention_days = 3
enable_security_features = true
enable_kms_advanced = true
enable_vpc_flow_logs = true
notification_email = "RRCloudDev@gmail.com"
EOF

print_success "✅ Study configurations updated"

# Step 5: Update study-deploy.sh
print_header "Updating study-deploy.sh..."
if ! grep -q "monitoring" study-deploy.sh; then
    sed -i '/        "database"|"db") deploy_domain "database-only" ;;/a\
        "monitoring"|"mon") deploy_domain "monitoring-only" ;;' study-deploy.sh
    
    sed -i '/  database        Deploy database-only configuration/a\
  monitoring      Deploy monitoring-only configuration' study-deploy.sh
fi

print_success "✅ study-deploy.sh updated"

# Step 6: Validate
print_header "Validating Terraform configuration..."
if terraform validate; then
    print_success "✅ Terraform configuration is valid!"
else
    print_warning "⚠️  Validation issues detected"
    terraform validate
fi

echo ""
print_success "🎉 CORRECTED Monitoring Module Implementation Complete!"
echo ""
print_status "What was fixed:"
echo "  ✅ All required variables now included"
echo "  ✅ Removed unsupported dashboard tags"
echo "  ✅ Simplified resource dependencies"
echo "  ✅ Added proper conditionals"
echo ""
print_status "Ready to deploy:"
echo "  ./study-deploy.sh monitoring     # Just monitoring"
echo "  ./study-deploy.sh domain4        # Full Domain 4"
echo ""
print_warning "Cost estimates:"
echo "  Monitoring-only: ~$2-5/day"
echo "  Domain 4: ~$10-18/day"
echo ""
print_success "This version should work without errors! 📊"
