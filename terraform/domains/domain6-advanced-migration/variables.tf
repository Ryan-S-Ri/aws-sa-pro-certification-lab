# Domain 6: Advanced Migration and Modernization Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for resources"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

# Application Migration Service variables
variable "enable_application_migration_service" {
  description = "Enable Application Migration Service (MGN)"
  type        = bool
  default     = false
}

variable "migration_instance_type" {
  description = "Instance type for migrated instances"
  type        = string
  default     = "t3.medium"
}

# Database Migration Service variables
variable "enable_database_migration_service" {
  description = "Enable Database Migration Service"
  type        = bool
  default     = false
}

variable "dms_instance_class" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.t3.micro"
}

variable "source_database_name" {
  description = "Source database name"
  type        = string
  default     = "sourcedb"
}

variable "source_database_host" {
  description = "Source database hostname"
  type        = string
  default     = "source-db.example.com"
}

variable "source_database_username" {
  description = "Source database username"
  type        = string
  default     = "admin"
}

variable "source_database_password" {
  description = "Source database password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "target_database_name" {
  description = "Target database name"
  type        = string
  default     = "targetdb"
}

variable "target_database_username" {
  description = "Target database username"
  type        = string
  default     = "admin"
}

variable "target_database_password" {
  description = "Target database password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "backup_retention_days" {
  description = "Database backup retention in days"
  type        = number
  default     = 7
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 1
}

variable "aurora_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.r5.large"
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights for Aurora"
  type        = bool
  default     = false
}

# Container Migration variables
variable "enable_container_migration" {
  description = "Enable container migration with ECS"
  type        = bool
  default     = false
}

variable "container_desired_count" {
  description = "Desired count of containers"
  type        = number
  default     = 2
}

variable "container_cpu" {
  description = "CPU units for container"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for container in MiB"
  type        = number
  default     = 512
}

variable "container_image" {
  description = "Container image URI"
  type        = string
  default     = "nginx:latest"
}

# Serverless Migration variables
variable "enable_serverless_migration" {
  description = "Enable serverless migration patterns"
  type        = bool
  default     = false
}

# Migration Orchestration variables
variable "enable_migration_orchestration" {
  description = "Enable Step Functions for migration orchestration"
  type        = bool
  default     = false
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
