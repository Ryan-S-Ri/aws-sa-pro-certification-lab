# Domain 6: Advanced Migration and Modernization Outputs

output "dms_replication_instance_arn" {
  description = "DMS replication instance ARN"
  value       = var.enable_database_migration_service ? aws_dms_replication_instance.migration[0].replication_instance_arn : null
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = var.enable_database_migration_service ? aws_rds_cluster.aurora_mysql[0].endpoint : null
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = var.enable_database_migration_service ? aws_rds_cluster.aurora_mysql[0].reader_endpoint : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.enable_container_migration ? aws_ecs_cluster.migration[0].name : null
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = var.enable_container_migration ? aws_ecs_service.migrated_app[0].name : null
}

output "lambda_function_name" {
  description = "Lambda function name for serverless migration"
  value       = var.enable_serverless_migration ? aws_lambda_function.migrated_function[0].function_name : null
}

output "step_function_arn" {
  description = "Step Functions state machine ARN"
  value       = var.enable_migration_orchestration ? aws_sfn_state_machine.migration_workflow[0].arn : null
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = var.enable_serverless_migration ? aws_api_gateway_rest_api.migrated_api[0].execution_arn : null
}
