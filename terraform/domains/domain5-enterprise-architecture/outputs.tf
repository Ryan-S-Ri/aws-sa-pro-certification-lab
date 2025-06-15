# Domain 5: Enterprise Architecture Outputs

output "organization_id" {
  description = "AWS Organization ID"
  value       = var.enable_organizations ? aws_organizations_organization.main[0].id : null
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = var.enable_organizations ? aws_organizations_organization.main[0].arn : null
}

output "security_baseline_policy_id" {
  description = "Security baseline SCP policy ID"
  value       = var.enable_organizations && var.enable_security_control_policies ? aws_organizations_policy.security_baseline[0].id : null
}

output "cross_account_admin_role_arn" {
  description = "Cross-account admin role ARN"
  value       = var.enable_cross_account_roles ? aws_iam_role.cross_account_admin[0].arn : null
}

output "cross_account_readonly_role_arn" {
  description = "Cross-account read-only role ARN"
  value       = var.enable_cross_account_roles ? aws_iam_role.cross_account_readonly[0].arn : null
}

output "enterprise_transit_gateway_id" {
  description = "Enterprise Transit Gateway ID"
  value       = var.enable_enterprise_transit_gateway ? aws_ec2_transit_gateway.enterprise[0].id : null
}

output "enterprise_transit_gateway_arn" {
  description = "Enterprise Transit Gateway ARN"
  value       = var.enable_enterprise_transit_gateway ? aws_ec2_transit_gateway.enterprise[0].arn : null
}

output "guardduty_detector_id" {
  description = "Enterprise GuardDuty detector ID"
  value       = var.enable_guardduty_enterprise ? aws_guardduty_detector.enterprise[0].id : null
}

output "security_hub_account_id" {
  description = "Security Hub account ID"
  value       = var.enable_security_hub_enterprise ? aws_securityhub_account.enterprise[0].id : null
}

output "config_aggregator_arn" {
  description = "Config aggregator ARN"
  value       = var.enable_config_aggregator ? aws_config_configuration_aggregator.enterprise[0].arn : null
}
