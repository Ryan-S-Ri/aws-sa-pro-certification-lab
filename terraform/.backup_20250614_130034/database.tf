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
resource "aws_dynamodb_table" "lab_table" {
  count          = var.enable_database_tier && var.enable_dynamodb ? 1 : 0
  provider       = aws.primary
  name           = "${local.common_name}-lab-table"
  billing_mode   = var.development_mode ? "PAY_PER_REQUEST" : "PROVISIONED"
  read_capacity  = var.development_mode ? null : 5
  write_capacity = var.development_mode ? null : 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Enable streams for Lambda triggers
  stream_enabled   = var.enable_dynamodb_streams
  stream_view_type = var.enable_dynamodb_streams ? "NEW_AND_OLD_IMAGES" : null

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
    Name = "${local.common_name}-lab-table"
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
