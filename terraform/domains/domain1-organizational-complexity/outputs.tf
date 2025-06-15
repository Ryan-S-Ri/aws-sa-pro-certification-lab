output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = try(aws_ec2_transit_gateway.main[0].id, null)
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account admin role"
  value       = aws_iam_role.cross_account_admin.arn
}

output "centralized_logging_bucket" {
  description = "Name of the centralized logging bucket"
  value       = aws_s3_bucket.centralized_logs.id
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = aws_config_configuration_recorder.main.name
}
