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
