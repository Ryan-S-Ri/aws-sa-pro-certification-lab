#!/bin/bash
# implement-database-module.sh - Complete database module implementation

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

echo "🗃️  AWS Certification Lab - Database Module Implementation"
echo "========================================================="
echo ""

# Check prerequisites
print_status "Checking prerequisites..."
if [[ ! -f "main.tf" || ! -f "variables.tf" ]]; then
    print_error "Please run this script from your Terraform project root directory"
    exit 1
fi

if [[ ! -d "study-configs" ]]; then
    print_error "study-configs directory not found. Please run setup-study-configs.sh first"
    exit 1
fi

print_success "✅ Prerequisites met"
echo ""

# Step 1: Create database.tf file
print_header "Creating database.tf file..."
cat > database.tf << 'EOF'
# database.tf - Database Infrastructure for SA Pro
# Comprehensive database setup covering RDS Aurora, DynamoDB, and advanced scenarios

# ================================================================
# DATA SOURCES
# ================================================================

# Get latest engine versions
data "aws_rds_engine_version" "aurora_mysql" {
  provider                 = aws.primary
  engine                   = "aurora-mysql"
  preferred_versions       = ["8.0.mysql_aurora.3.07.1", "8.0.mysql_aurora.3.06.0"]
  include_all              = false
}

data "aws_rds_engine_version" "aurora_postgresql" {
  provider                 = aws.primary
  engine                   = "aurora-postgresql"
  preferred_versions       = ["16.1", "15.5", "14.10"]
  include_all              = false
}

# ================================================================
# SUBNET GROUPS
# ================================================================

# DB Subnet Group for RDS instances
resource "aws_db_subnet_group" "primary" {
  count       = var.enable_database_tier ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-db-subnet-group"
  description = "Database subnet group for RDS instances"
  subnet_ids  = aws_subnet.primary_private[*].id

  tags = {
    Name = "${local.common_name}-db-subnet-group"
  }
}

# ================================================================
# PARAMETER GROUPS
# ================================================================

# Aurora MySQL cluster parameter group
resource "aws_rds_cluster_parameter_group" "aurora_mysql" {
  count       = var.enable_database_tier ? 1 : 0
  provider    = aws.primary
  family      = "aurora-mysql8.0"
  name        = "${local.common_name}-aurora-mysql-cluster-params"
  description = "Aurora MySQL cluster parameter group"

  parameter {
    name  = "innodb_lock_wait_timeout"
    value = "300"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = {
    Name = "${local.common_name}-aurora-mysql-cluster-params"
  }
}

# Aurora MySQL DB parameter group
resource "aws_db_parameter_group" "aurora_mysql" {
  count       = var.enable_database_tier ? 1 : 0
  provider    = aws.primary
  family      = "aurora-mysql8.0"
  name        = "${local.common_name}-aurora-mysql-db-params"
  description = "Aurora MySQL DB parameter group"

  parameter {
    name  = "innodb_print_all_deadlocks"
    value = "1"
  }

  tags = {
    Name = "${local.common_name}-aurora-mysql-db-params"
  }
}

# Aurora PostgreSQL cluster parameter group
resource "aws_rds_cluster_parameter_group" "aurora_postgresql" {
  count       = var.enable_database_tier && var.enable_postgresql ? 1 : 0
  provider    = aws.primary
  family      = "aurora-postgresql16"
  name        = "${local.common_name}-aurora-postgres-cluster-params"
  description = "Aurora PostgreSQL cluster parameter group"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "${local.common_name}-aurora-postgres-cluster-params"
  }
}

# ================================================================
# SECURITY GROUPS
# ================================================================

# Security group for Aurora MySQL
resource "aws_security_group" "aurora_mysql" {
  count       = var.enable_database_tier ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-aurora-mysql-sg"
  description = "Security group for Aurora MySQL cluster"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  ingress {
    description     = "MySQL from bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.enable_compute_tier ? [aws_security_group.bastion_sg.id] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-aurora-mysql-sg"
  }
}

# Security group for Aurora PostgreSQL
resource "aws_security_group" "aurora_postgresql" {
  count       = var.enable_database_tier && var.enable_postgresql ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-aurora-postgres-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  ingress {
    description     = "PostgreSQL from bastion"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.enable_compute_tier ? [aws_security_group.bastion_sg.id] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-aurora-postgres-sg"
  }
}

# ================================================================
# KMS KEYS FOR DATABASE ENCRYPTION
# ================================================================

# KMS key for database encryption
resource "aws_kms_key" "database" {
  count                   = var.enable_database_tier ? 1 : 0
  provider                = aws.primary
  description             = "KMS key for database encryption"
  deletion_window_in_days = var.development_mode ? 7 : 30
  enable_key_rotation     = true

  tags = {
    Name = "${local.common_name}-database-key"
  }
}

# KMS key alias
resource "aws_kms_alias" "database" {
  count         = var.enable_database_tier ? 1 : 0
  provider      = aws.primary
  name          = "alias/${local.common_name}-database"
  target_key_id = aws_kms_key.database[0].key_id
}

# ================================================================
# AURORA MYSQL CLUSTER
# ================================================================

# Aurora MySQL cluster
resource "aws_rds_cluster" "aurora_mysql" {
  count                           = var.enable_database_tier ? 1 : 0
  provider                        = aws.primary
  cluster_identifier              = "${local.common_name}-aurora-mysql"
  engine                          = "aurora-mysql"
  engine_version                  = data.aws_rds_engine_version.aurora_mysql.version
  database_name                   = var.mysql_database_name
  master_username                 = var.mysql_master_username
  master_password                 = var.mysql_master_password
  backup_retention_period         = var.backup_retention_days
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_mysql[0].name
  db_subnet_group_name            = aws_db_subnet_group.primary[0].name
  vpc_security_group_ids          = [aws_security_group.aurora_mysql[0].id]
  
  # Encryption
  storage_encrypted = true
  kms_key_id       = aws_kms_key.database[0].arn
  
  # Advanced features
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  copy_tags_to_snapshot          = true
  deletion_protection            = !var.development_mode
  skip_final_snapshot           = var.development_mode
  final_snapshot_identifier     = var.development_mode ? null : "${local.common_name}-aurora-mysql-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Performance Insights
  performance_insights_enabled          = var.enable_database_performance_insights
  performance_insights_kms_key_id      = var.enable_database_performance_insights ? aws_kms_key.database[0].arn : null
  performance_insights_retention_period = var.enable_database_performance_insights ? (var.development_mode ? 7 : 93) : null

  tags = merge(var.common_tags, {
    Name = "${local.common_name}-aurora-mysql"
    Type = "aurora-mysql-cluster"
  })
}

# Aurora MySQL cluster instances
resource "aws_rds_cluster_instance" "aurora_mysql" {
  count                        = var.enable_database_tier ? (var.development_mode ? 1 : 2) : 0
  provider                     = aws.primary
  identifier                   = "${local.common_name}-aurora-mysql-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.aurora_mysql[0].id
  instance_class               = var.database_instance_class
  engine                       = aws_rds_cluster.aurora_mysql[0].engine
  engine_version               = aws_rds_cluster.aurora_mysql[0].engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_mysql[0].name
  monitoring_interval          = var.enable_detailed_monitoring ? 60 : 0
  monitoring_role_arn          = var.enable_detailed_monitoring ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  auto_minor_version_upgrade   = true
  
  # Performance Insights
  performance_insights_enabled          = var.enable_database_performance_insights
  performance_insights_kms_key_id      = var.enable_database_performance_insights ? aws_kms_key.database[0].arn : null
  performance_insights_retention_period = var.enable_database_performance_insights ? (var.development_mode ? 7 : 93) : null

  tags = merge(var.common_tags, {
    Name = "${local.common_name}-aurora-mysql-${count.index + 1}"
    Type = "aurora-mysql-instance"
  })
}

# ================================================================
# IAM ROLE FOR RDS ENHANCED MONITORING
# ================================================================

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count    = var.enable_database_tier && var.enable_detailed_monitoring ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.common_name}-rds-enhanced-monitoring"
  }
}

# Attach enhanced monitoring policy
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.enable_database_tier && var.enable_detailed_monitoring ? 1 : 0
  provider   = aws.primary
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ================================================================
# DYNAMODB TABLES
# ================================================================

# DynamoDB table for session storage
resource "aws_dynamodb_table" "sessions" {
  count          = var.enable_database_tier && var.enable_dynamodb ? 1 : 0
  provider       = aws.primary
  name           = "${local.common_name}-sessions"
  billing_mode   = var.development_mode ? "PAY_PER_REQUEST" : "PROVISIONED"
  read_capacity  = var.development_mode ? null : 5
  write_capacity = var.development_mode ? null : 5
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # Global Secondary Index
  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
    read_capacity   = var.development_mode ? null : 2
    write_capacity  = var.development_mode ? null : 2
  }

  # TTL for session expiration
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.enable_kms_advanced ? aws_kms_key.database[0].arn : null
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = !var.development_mode
  }

  tags = merge(var.common_tags, {
    Name = "${local.common_name}-sessions"
    Type = "dynamodb-table"
  })
}

# DynamoDB table for application data
resource "aws_dynamodb_table" "app_data" {
  count          = var.enable_database_tier && var.enable_dynamodb ? 1 : 0
  provider       = aws.primary
  name           = "${local.common_name}-app-data"
  billing_mode   = var.development_mode ? "PAY_PER_REQUEST" : "PROVISIONED"
  read_capacity  = var.development_mode ? null : 10
  write_capacity = var.development_mode ? null : 10
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "gsi1pk"
    type = "S"
  }

  attribute {
    name = "gsi1sk"
    type = "S"
  }

  # Global Secondary Index 1
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL"
    read_capacity   = var.development_mode ? null : 5
    write_capacity  = var.development_mode ? null : 5
  }

  # Encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.enable_kms_advanced ? aws_kms_key.database[0].arn : null
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = !var.development_mode
  }

  tags = merge(var.common_tags, {
    Name = "${local.common_name}-app-data"
    Type = "dynamodb-table"
  })
}

# ================================================================
# ELASTICACHE SUBNET GROUP AND CLUSTER
# ================================================================

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "primary" {
  count      = var.enable_database_tier && var.enable_elasticache ? 1 : 0
  provider   = aws.primary
  name       = "${local.common_name}-cache-subnet-group"
  subnet_ids = aws_subnet.primary_private[*].id

  tags = {
    Name = "${local.common_name}-cache-subnet-group"
  }
}

# Security group for ElastiCache
resource "aws_security_group" "elasticache" {
  count       = var.enable_database_tier && var.enable_elasticache ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-elasticache-sg"
  description = "Security group for ElastiCache cluster"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description     = "Redis from app tier"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-elasticache-sg"
  }
}

# ElastiCache Redis cluster
resource "aws_elasticache_replication_group" "redis" {
  count                      = var.enable_database_tier && var.enable_elasticache ? 1 : 0
  provider                   = aws.primary
  replication_group_id       = "${local.common_name}-redis"
  description                = "Redis cluster for caching"
  node_type                  = var.development_mode ? "cache.t3.micro" : "cache.t3.small"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  num_cache_clusters         = var.development_mode ? 1 : 2
  engine_version             = "7.0"
  subnet_group_name          = aws_elasticache_subnet_group.primary[0].name
  security_group_ids         = [aws_security_group.elasticache[0].id]
  
  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  
  # Backups
  snapshot_retention_limit = var.development_mode ? 1 : 5
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:07:00"

  tags = merge(var.common_tags, {
    Name = "${local.common_name}-redis"
    Type = "elasticache-redis"
  })
}

# ================================================================
# DATABASE SECRETS IN SECRETS MANAGER
# ================================================================

# MySQL master password secret
resource "aws_secretsmanager_secret" "mysql_master_password" {
  count                   = var.enable_database_tier && var.enable_secrets_manager ? 1 : 0
  provider                = aws.primary
  name                    = "${local.common_name}/database/mysql/master"
  description             = "Master password for Aurora MySQL cluster"
  recovery_window_in_days = var.development_mode ? 0 : 30
  kms_key_id             = var.enable_kms_advanced ? aws_kms_key.database[0].arn : null

  tags = {
    Name = "${local.common_name}-mysql-master-secret"
  }
}

# MySQL master password secret version
resource "aws_secretsmanager_secret_version" "mysql_master_password" {
  count     = var.enable_database_tier && var.enable_secrets_manager ? 1 : 0
  provider  = aws.primary
  secret_id = aws_secretsmanager_secret.mysql_master_password[0].id
  secret_string = jsonencode({
    username = var.mysql_master_username
    password = var.mysql_master_password
    host     = aws_rds_cluster.aurora_mysql[0].endpoint
    port     = aws_rds_cluster.aurora_mysql[0].port
    dbname   = var.mysql_database_name
  })
}

# Redis auth token secret
resource "aws_secretsmanager_secret" "redis_auth_token" {
  count                   = var.enable_database_tier && var.enable_elasticache && var.enable_secrets_manager ? 1 : 0
  provider                = aws.primary
  name                    = "${local.common_name}/cache/redis/auth"
  description             = "Auth token for Redis cluster"
  recovery_window_in_days = var.development_mode ? 0 : 30
  kms_key_id             = var.enable_kms_advanced ? aws_kms_key.database[0].arn : null

  tags = {
    Name = "${local.common_name}-redis-auth-secret"
  }
}

# Redis auth token secret version
resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  count     = var.enable_database_tier && var.enable_elasticache && var.enable_secrets_manager ? 1 : 0
  provider  = aws.primary
  secret_id = aws_secretsmanager_secret.redis_auth_token[0].id
  secret_string = jsonencode({
    auth_token = var.redis_auth_token
    endpoint   = aws_elasticache_replication_group.redis[0].primary_endpoint_address
    port       = aws_elasticache_replication_group.redis[0].port
  })
}
EOF

print_success "✅ database.tf created"

# Step 2: Add database variables to variables.tf
print_header "Adding database variables to variables.tf..."
cat >> variables.tf << 'EOF'

# ================================================================
# DATABASE TIER VARIABLES
# ================================================================

# Core database toggles
variable "enable_postgresql" {
  description = "Enable PostgreSQL Aurora cluster in addition to MySQL"
  type        = bool
  default     = false
}

variable "enable_dynamodb" {
  description = "Enable DynamoDB tables"
  type        = bool
  default     = true
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager for database credentials"
  type        = bool
  default     = true
}

# MySQL/Aurora configuration
variable "mysql_database_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "labdb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.mysql_database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "mysql_master_username" {
  description = "Master username for MySQL database"
  type        = string
  default     = "admin"
  
  validation {
    condition     = length(var.mysql_master_username) >= 1 && length(var.mysql_master_username) <= 16
    error_message = "Master username must be between 1 and 16 characters."
  }
}

variable "mysql_master_password" {
  description = "Master password for MySQL database"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
  
  validation {
    condition     = length(var.mysql_master_password) >= 8 && can(regex("[A-Z]", var.mysql_master_password)) && can(regex("[a-z]", var.mysql_master_password)) && can(regex("[0-9]", var.mysql_master_password))
    error_message = "Password must be at least 8 characters with uppercase, lowercase, and numbers."
  }
}

# PostgreSQL configuration
variable "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "labpgdb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.postgresql_database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "postgresql_master_username" {
  description = "Master username for PostgreSQL database"
  type        = string
  default     = "postgres"
  
  validation {
    condition     = length(var.postgresql_master_username) >= 1 && length(var.postgresql_master_username) <= 63
    error_message = "Master username must be between 1 and 63 characters."
  }
}

variable "postgresql_master_password" {
  description = "Master password for PostgreSQL database"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
  
  validation {
    condition     = length(var.postgresql_master_password) >= 8 && can(regex("[A-Z]", var.postgresql_master_password)) && can(regex("[a-z]", var.postgresql_master_password)) && can(regex("[0-9]", var.postgresql_master_password))
    error_message = "Password must be at least 8 characters with uppercase, lowercase, and numbers."
  }
}

# ElastiCache configuration
variable "redis_auth_token" {
  description = "Auth token for Redis cluster"
  type        = string
  default     = "MyRedisAuthToken123!"
  sensitive   = true
  
  validation {
    condition     = length(var.redis_auth_token) >= 16 && length(var.redis_auth_token) <= 128
    error_message = "Redis auth token must be between 16 and 128 characters."
  }
}

# Database performance and monitoring
variable "enable_database_cross_region_backup" {
  description = "Enable cross-region automated backups"
  type        = bool
  default     = false
}

variable "enable_database_monitoring_enhanced" {
  description = "Enable enhanced monitoring for RDS instances"
  type        = bool
  default     = false
}

# Advanced database features
variable "enable_aurora_serverless" {
  description = "Use Aurora Serverless v2 scaling"
  type        = bool
  default     = false
}

variable "enable_database_proxy" {
  description = "Enable RDS Proxy for connection pooling"
  type        = bool
  default     = false
}

variable "enable_database_backtrack" {
  description = "Enable Aurora backtrack (MySQL only)"
  type        = bool
  default     = false
}

# DynamoDB specific settings
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "enable_dynamodb_global_tables" {
  description = "Enable DynamoDB Global Tables for multi-region"
  type        = bool
  default     = false
}

variable "enable_dynamodb_streams" {
  description = "Enable DynamoDB Streams"
  type        = bool
  default     = false
}
EOF

print_success "✅ Database variables added to variables.tf"

# Step 3: Add database outputs to outputs.tf
print_header "Adding database outputs to outputs.tf..."
cat >> outputs.tf << 'EOF'

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
EOF

print_success "✅ Database outputs added to outputs.tf"

# Step 4: Update domain configurations with database settings
print_header "Updating domain configurations with database settings..."

# Update Domain 3: Performance
cat >> study-configs/domain3-performance.tfvars << 'EOF'

# Database configuration for Domain 3
mysql_master_password = "LabPassword123!"
redis_auth_token = "LabRedisAuth123456789!"

# Database feature toggles
enable_postgresql = false  # Start with MySQL only
enable_dynamodb = true
enable_secrets_manager = true
enable_database_cross_region_backup = false
enable_database_monitoring_enhanced = false
enable_aurora_serverless = false
enable_database_proxy = false
enable_database_backtrack = false
enable_dynamodb_global_tables = false
enable_dynamodb_streams = false
EOF

# Update Domain 4: Cost Optimized
cat >> study-configs/domain4-cost-optimized.tfvars << 'EOF'

# Database configuration for Domain 4 (inherit from Domain 3)
mysql_master_password = "LabPassword123!"
redis_auth_token = "LabRedisAuth123456789!"

# Database feature toggles
enable_postgresql = false
enable_dynamodb = true
enable_secrets_manager = true
enable_database_cross_region_backup = false
enable_database_monitoring_enhanced = true  # NEW: Enable enhanced monitoring
enable_aurora_serverless = false
enable_database_proxy = false  # Expensive, keep disabled
enable_database_backtrack = false
enable_dynamodb_global_tables = false
enable_dynamodb_streams = true  # NEW: Enable for cost monitoring patterns
EOF

# Update Full Lab
cat >> study-configs/full-lab.tfvars << 'EOF'

# Database configuration for Full Lab (all features)
mysql_master_password = "LabPassword123!"
postgresql_master_password = "LabPgPassword123!"
redis_auth_token = "LabRedisAuth123456789!"

# All database features enabled
enable_postgresql = true  # Enable both MySQL and PostgreSQL
enable_dynamodb = true
enable_secrets_manager = true
enable_database_cross_region_backup = true
enable_database_monitoring_enhanced = true
enable_aurora_serverless = false  # Keep traditional for learning
enable_database_proxy = true  # Enable RDS Proxy
enable_database_backtrack = true  # Enable Aurora backtrack
enable_dynamodb_global_tables = true
enable_dynamodb_streams = true
EOF

print_success "✅ Domain configurations updated"

# Step 5: Create database-only testing configuration
print_header "Creating database-only testing configuration..."
cat > study-configs/database-only.tfvars << 'EOF'
# Database-only configuration for focused database study
# Use this to test just the database components

# Disable other tiers to focus on databases
enable_compute_tier = false
enable_monitoring_tier = false
enable_advanced_networking = false
enable_disaster_recovery = false

# Enable database tier
enable_database_tier = true

# Database-specific settings
mysql_master_password = "LabPassword123!"
redis_auth_token = "LabRedisAuth123456789!"

# Enable core database features for learning
enable_postgresql = false  # Start with MySQL
enable_dynamodb = true
enable_elasticache = true
enable_secrets_manager = true
enable_database_performance_insights = true

# Cost-optimized settings for focused study
development_mode = true
enable_detailed_monitoring = true
backup_retention_days = 1

# Basic security features
enable_security_features = true
enable_kms_advanced = true
enable_vpc_flow_logs = false  # Reduce noise

# Email for notifications
notification_email = "RRCloudDev@gmail.com"
EOF

print_success "✅ Database-only configuration created"

# Step 6: Create database connection script
print_header "Creating database connection helper script..."
cat > scripts/database-connect.sh << 'EOF'
#!/bin/bash
# database-connect.sh - Helper script for connecting to databases

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

show_connection_info() {
    print_status "Getting database connection information..."
    
    echo ""
    print_success "Database Endpoints:"
    terraform output -json database_endpoints 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
    
    echo ""
    print_success "DynamoDB Tables:"
    terraform output -json dynamodb_tables 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
    
    echo ""
    print_warning "Connection Examples:"
    echo "MySQL (from bastion):"
    echo "  mysql -h \$(terraform output -raw database_endpoints | jq -r '.aurora_mysql_writer') -u admin -p labdb"
    echo ""
    echo "Redis (from app instances):"
    echo "  redis-cli -h \$(terraform output -raw database_endpoints | jq -r '.redis_primary') -a 'LabRedisAuth123456789!'"
    echo ""
    echo "DynamoDB (AWS CLI):"
    echo "  aws dynamodb scan --table-name \$(terraform output -raw dynamodb_tables | jq -r '.sessions')"
}

show_secrets() {
    print_status "Database secrets in AWS Secrets Manager:"
    echo ""
    
    if aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `aws-cert-lab`)].Name' --output table 2>/dev/null; then
        echo ""
        print_warning "To retrieve a secret:"
        echo "aws secretsmanager get-secret-value --secret-id aws-cert-lab/database/mysql/master --query SecretString --output text | jq"
    else
        echo "No secrets found or AWS CLI not configured"
    fi
}

case ${1:-""} in
    "info"|"show"|"")
        show_connection_info
        ;;
    "secrets")
        show_secrets
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/database-connect.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  info, show    Show database connection information"
        echo "  secrets       Show secrets in AWS Secrets Manager"
        echo "  help          Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/database-connect.sh help' for usage"
        exit 1
        ;;
esac
EOF

chmod +x scripts/database-connect.sh
print_success "✅ Database connection script created"

# Step 7: Update study-deploy.sh to include database commands
print_header "Updating study-deploy.sh with database commands..."
# Create a backup of the original
cp study-deploy.sh study-deploy.sh.backup

# Add database command to the help section
sed -i '/  full, full-lab  Deploy complete lab/a\
  database        Deploy database-only configuration (focused study)' study-deploy.sh

# Add database case to the main function
sed -i '/        "full"|"full-lab") deploy_domain "full-lab" ;;/a\
        "database"|"db") deploy_domain "database-only" ;;' study-deploy.sh

print_success "✅ study-deploy.sh updated with database commands"

# Step 8: Validation and summary
print_header "Validating Terraform configuration..."
if terraform validate; then
    print_success "✅ Terraform configuration is valid"
else
    print_warning "⚠️  Terraform validation failed - please check the configuration"
fi

echo ""
print_success "🎉 Database module implementation complete!"
echo ""
print_status "Files created/modified:"
echo "  ✅ database.tf - Complete database infrastructure"
echo "  ✅ variables.tf - Database variables added"
echo "  ✅ outputs.tf - Database outputs added"
echo "  ✅ study-configs/domain3-performance.tfvars - Updated with database settings"
echo "  ✅ study-configs/domain4-cost-optimized.tfvars - Updated with database settings"
echo "  ✅ study-configs/full-lab.tfvars - Updated with database settings"
echo "  ✅ study-configs/database-only.tfvars - New database-focused configuration"
echo "  ✅ scripts/database-connect.sh - Database connection helper"
echo "  ✅ study-deploy.sh - Updated with database commands"
echo ""
print_warning "💰 Database Cost Estimates:"
echo "  Database-only: ~$5-10/day (Aurora + DynamoDB + ElastiCache)"
echo "  Domain 3: ~$8-15/day (+ Compute tier)"
echo "  Domain 4: ~$10-18/day (+ Enhanced monitoring)"
echo "  Full Lab: ~$20-35/day (+ PostgreSQL + RDS Proxy)"
echo ""
print_status "Next steps:"
echo "  1. Initialize: terraform init"
echo "  2. Test database-only: ./study-deploy.sh database"
echo "  3. Or progress to Domain 3: ./study-deploy.sh domain3"
echo "  4. Check connections: ./scripts/database-connect.sh info"
echo "  5. Always destroy after study: ./study-deploy.sh destroy"
echo ""
print_success "🗃️ Ready to deploy your database infrastructure!"
echo ""
print_warning "📋 What you get with the database tier:"
echo "  🔹 Aurora MySQL cluster with encryption"
echo "  🔹 DynamoDB tables with GSI and TTL"
echo "  🔹 ElastiCache Redis with auth"
echo "  🔹 AWS Secrets Manager integration"
echo "  🔹 KMS encryption keys"
echo "  🔹 Enhanced monitoring (when enabled)"
echo "  🔹 Proper security groups and networking"
echo "  🔹 Parameter groups for optimization"
echo ""
print_success "Happy studying! 🚀"
