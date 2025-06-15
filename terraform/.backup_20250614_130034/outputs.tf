# Outputs for AWS Certification Lab

output "account_id" {
  description = "AWS Account ID"
  value       = local.account_id
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "lab_bucket_name" {
  description = "Name of the lab S3 bucket"
  value       = aws_s3_bucket.lab_bucket.id
}

output "terraform_managed_by" {
  description = "What is managing this infrastructure"
  value       = "Raspberry Pi"
}

# ================================================================
# DATABASE TIER OUTPUTS
# ================================================================

output "database_endpoints" {
  description = "Database connection endpoints"
  value = var.enable_database_tier ? {
    aurora_mysql_writer = aws_rds_cluster.aurora_mysql[0].endpoint
    aurora_mysql_reader = aws_rds_cluster.aurora_mysql[0].reader_endpoint
    redis_primary = var.enable_elasticache ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : "Not deployed"
  } : {}
  sensitive = true
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value = var.enable_database_tier && var.enable_dynamodb ? {
    sessions = aws_dynamodb_table.sessions[0].name
    app_data = aws_dynamodb_table.app_data[0].name
  } : {}
}

output "database_security_groups" {
  description = "Database security group IDs"
  value = var.enable_database_tier ? {
    aurora_mysql = aws_security_group.aurora_mysql[0].id
    elasticache = var.enable_elasticache ? aws_security_group.elasticache[0].id : "Not deployed"
  } : {}
}

output "database_kms_key" {
  description = "KMS key for database encryption"
  value       = var.enable_database_tier ? aws_kms_key.database[0].arn : "Not deployed"
}

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

# ================================================================
# SECURITY & IDENTITY OUTPUTS
# ================================================================


# ================================================================
# SECURITY & IDENTITY OUTPUTS
# ================================================================


# ================================================================
# SECURITY & IDENTITY OUTPUTS
# ================================================================


# ================================================================
# SECURITY & IDENTITY OUTPUTS
# ================================================================


# ================================================================
# SECURITY & IDENTITY OUTPUTS
# ================================================================

output "security_kms_key" {
  description = "KMS key for security services"
  value       = var.enable_security_tier ? aws_kms_key.security[0].arn : "Not deployed"
}

output "acm_certificate" {
  description = "ACM certificate details"
  value = var.enable_security_tier && var.enable_certificate_manager ? {
    arn         = aws_acm_certificate.main[0].arn
    domain_name = aws_acm_certificate.main[0].domain_name
    status      = aws_acm_certificate.main[0].status
  } : {}
}

output "route53_zone" {
  description = "Route 53 hosted zone details"
  value = var.enable_security_tier && var.enable_certificate_manager && var.create_route53_zone ? {
    zone_id     = aws_route53_zone.main[0].zone_id
    name_servers = aws_route53_zone.main[0].name_servers
  } : {}
}

output "systems_manager_parameters" {
  description = "Systems Manager parameter names"
  value = var.enable_security_tier && var.enable_systems_manager ? {
    db_password = aws_ssm_parameter.db_password[0].name
    redis_token = aws_ssm_parameter.redis_token[0].name
    app_config  = aws_ssm_parameter.app_config[0].name
  } : {}
  sensitive = true
}

output "cloudtrail_details" {
  description = "CloudTrail configuration"
  value = var.enable_security_tier && var.enable_cloudtrail_advanced ? {
    trail_arn    = aws_cloudtrail.main[0].arn
    s3_bucket    = aws_s3_bucket.cloudtrail[0].bucket
    kms_key_id   = aws_cloudtrail.main[0].kms_key_id
  } : {}
}

output "guardduty_detector" {
  description = "GuardDuty detector details"
  value = var.enable_security_tier && var.enable_guardduty ? {
    detector_id = aws_guardduty_detector.main[0].id
    status      = aws_guardduty_detector.main[0].enable
  } : {}
}

output "config_recorder" {
  description = "AWS Config recorder details"
  value = var.enable_security_tier && var.enable_aws_config ? {
    recorder_name = aws_config_configuration_recorder.main[0].name
    role_arn      = aws_config_configuration_recorder.main[0].role_arn
  } : {}
}

output "security_iam_roles" {
  description = "Security IAM role ARNs"
  value = var.enable_security_tier ? {
    security_auditor = var.enable_advanced_iam ? aws_iam_role.security_auditor[0].arn : "Not enabled"
    cross_account    = var.enable_cross_account_roles ? aws_iam_role.cross_account_access[0].arn : "Not enabled"
    config_role      = var.enable_aws_config ? aws_iam_role.config[0].arn : "Not enabled"
  } : {}
}
