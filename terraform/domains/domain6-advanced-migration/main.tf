# Domain 6: Advanced Migration and Modernization
# Covers: Application Migration Service, Container migration, Serverless patterns, Database migration strategies

# Local variables for this domain
locals {
  domain_name = "domain6-advanced-migration"
  domain_tags = merge(var.common_tags, {
    Domain = "Advanced Migration and Modernization"
    ExamDomain = "Domain6"
  })
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# Archive files for Lambda functions
data "archive_file" "lambda_zip" {
  count = var.enable_serverless_migration ? 1 : 0

  type        = "zip"
  output_path = "/tmp/lambda_function.zip"
  
  source {
    content = <<-LAMBDA_CODE
import json
import boto3

def handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Migrated function executed successfully',
            'event': event
        })
    }
LAMBDA_CODE
    filename = "index.py"
  }
}

data "archive_file" "validator_zip" {
  count = var.enable_migration_orchestration ? 1 : 0

  type        = "zip"
  output_path = "/tmp/validator_function.zip"
  
  source {
    content = <<-VALIDATOR_CODE
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info(f"Validation event: {json.dumps(event)}")
    
    validation_results = {
        'database_connectivity': True,
        'application_health': True,
        'network_connectivity': True,
        'security_compliance': True
    }
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'validation_status': 'passed',
            'results': validation_results,
            'timestamp': context.aws_request_id
        })
    }
VALIDATOR_CODE
    filename = "index.py"
  }
}

data "archive_file" "migrator_zip" {
  count = var.enable_migration_orchestration ? 1 : 0

  type        = "zip"
  output_path = "/tmp/migrator_function.zip"
  
  source {
    content = <<-MIGRATOR_CODE
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info(f"Migration event: {json.dumps(event)}")
    
    migration_results = {
        'containers_deployed': True,
        'load_balancer_configured': True,
        'auto_scaling_enabled': True,
        'monitoring_configured': True
    }
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'migration_status': 'completed',
            'results': migration_results,
            'timestamp': context.aws_request_id
        })
    }
MIGRATOR_CODE
    filename = "index.py"
  }
}

# Launch Template for migrated instances
resource "aws_launch_template" "migrated_instances" {
  count = var.enable_application_migration_service ? 1 : 0

  name_prefix   = "${var.project_name}-migrated-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.migration_instance_type

  vpc_security_group_ids = [aws_security_group.migration[0].id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.domain_tags, {
      Name = "${var.project_name}-migrated-instance"
      MigrationType = "Lift-and-Shift"
    })
  }

  user_data = base64encode(<<-USERDATA
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

echo "Migration setup completed for ${var.project_name}" > /tmp/migration-setup.log
USERDATA
  )

  tags = local.domain_tags
}

# DMS Replication Subnet Group
resource "aws_dms_replication_subnet_group" "migration" {
  count = var.enable_database_migration_service ? 1 : 0

  replication_subnet_group_description = "DMS replication subnet group for ${var.project_name}"
  replication_subnet_group_id         = "${var.project_name}-dms-subnet-group"
  subnet_ids                          = var.subnet_ids

  tags = local.domain_tags
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "migration" {
  count = var.enable_database_migration_service ? 1 : 0

  allocated_storage            = 50
  apply_immediately           = true
  auto_minor_version_upgrade  = true
  availability_zone           = data.aws_availability_zones.available.names[0]
  engine_version              = "3.5.2"
  multi_az                    = false
  publicly_accessible         = false
  replication_instance_class   = var.dms_instance_class
  replication_instance_id      = "${var.project_name}-dms-instance"
  replication_subnet_group_id  = aws_dms_replication_subnet_group.migration[0].id

  tags = local.domain_tags

  vpc_security_group_ids = [aws_security_group.dms[0].id]

  depends_on = [
    aws_dms_replication_subnet_group.migration
  ]
}

# DMS Source Endpoint (MySQL example)
resource "aws_dms_endpoint" "source" {
  count = var.enable_database_migration_service ? 1 : 0

  certificate_arn      = ""
  database_name        = var.source_database_name
  endpoint_id          = "${var.project_name}-source-endpoint"
  endpoint_type        = "source"
  engine_name          = "mysql"
  password             = var.source_database_password
  port                 = 3306
  server_name          = var.source_database_host
  ssl_mode             = "none"
  username             = var.source_database_username

  tags = local.domain_tags
}

# DMS Target Endpoint (Aurora MySQL)
resource "aws_dms_endpoint" "target" {
  count = var.enable_database_migration_service ? 1 : 0

  certificate_arn = ""
  database_name   = aws_rds_cluster.aurora_mysql[0].database_name
  endpoint_id     = "${var.project_name}-target-endpoint"
  endpoint_type   = "target"
  engine_name     = "aurora"
  password        = var.target_database_password
  port            = 3306
  server_name     = aws_rds_cluster.aurora_mysql[0].endpoint
  ssl_mode        = "none"
  username        = aws_rds_cluster.aurora_mysql[0].master_username

  tags = local.domain_tags
}

# Aurora MySQL Cluster for migration target
resource "aws_rds_cluster" "aurora_mysql" {
  count = var.enable_database_migration_service ? 1 : 0

  cluster_identifier      = "${var.project_name}-aurora-mysql"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.04.0"
  database_name          = var.target_database_name
  master_username        = var.target_database_username
  master_password        = var.target_database_password
  backup_retention_period = var.backup_retention_days
  preferred_backup_window = "07:00-09:00"
  db_subnet_group_name   = aws_db_subnet_group.aurora[0].name
  vpc_security_group_ids = [aws_security_group.aurora[0].id]
  
  skip_final_snapshot = true
  deletion_protection = false

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = local.domain_tags
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count = var.enable_database_migration_service ? var.aurora_instance_count : 0

  identifier         = "${var.project_name}-aurora-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_mysql[0].id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.aurora_mysql[0].engine
  engine_version     = aws_rds_cluster.aurora_mysql[0].engine_version

  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = 60
  monitoring_role_arn         = aws_iam_role.rds_enhanced_monitoring[0].arn

  tags = local.domain_tags
}

# ECS Cluster for container migration
resource "aws_ecs_cluster" "migration" {
  count = var.enable_container_migration ? 1 : 0

  name = "${var.project_name}-migration-cluster"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs[0].name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.domain_tags
}

# ECS Service for migrated application
resource "aws_ecs_service" "migrated_app" {
  count = var.enable_container_migration ? 1 : 0

  name            = "${var.project_name}-migrated-app"
  cluster         = aws_ecs_cluster.migration[0].id
  task_definition = aws_ecs_task_definition.migrated_app[0].arn
  desired_count   = var.container_desired_count

  network_configuration {
    security_groups  = [aws_security_group.ecs[0].id]
    subnets         = var.subnet_ids
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
  }

  tags = local.domain_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "migrated_app" {
  count = var.enable_container_migration ? 1 : 0

  family                = "${var.project_name}-migrated-app"
  network_mode          = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                   = var.container_cpu
  memory                = var.container_memory
  execution_role_arn    = aws_iam_role.ecs_execution[0].arn
  task_role_arn        = aws_iam_role.ecs_task[0].arn

  container_definitions = jsonencode([
    {
      name  = "migrated-app"
      image = var.container_image
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs[0].name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = [
        {
          name  = "ENV"
          value = var.environment
        },
        {
          name  = "APP_NAME"
          value = var.project_name
        }
      ]
    }
  ])

  tags = local.domain_tags
}

# Lambda function for serverless migration pattern
resource "aws_lambda_function" "migrated_function" {
  count = var.enable_serverless_migration ? 1 : 0

  filename         = data.archive_file.lambda_zip[0].output_path
  function_name    = "${var.project_name}-migrated-function"
  role            = aws_iam_role.lambda[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = local.domain_tags
}

# API Gateway for serverless migration
resource "aws_api_gateway_rest_api" "migrated_api" {
  count = var.enable_serverless_migration ? 1 : 0

  name        = "${var.project_name}-migrated-api"
  description = "API for migrated serverless application"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.domain_tags
}

# Additional Lambda functions for migration workflow
resource "aws_lambda_function" "migration_validator" {
  count = var.enable_migration_orchestration ? 1 : 0

  filename         = data.archive_file.validator_zip[0].output_path
  function_name    = "${var.project_name}-migration-validator"
  role            = aws_iam_role.lambda[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.validator_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = local.domain_tags
}

resource "aws_lambda_function" "app_migrator" {
  count = var.enable_migration_orchestration ? 1 : 0

  filename         = data.archive_file.migrator_zip[0].output_path
  function_name    = "${var.project_name}-app-migrator"
  role            = aws_iam_role.lambda[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.migrator_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 900

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = local.domain_tags
}

# Step Functions for workflow orchestration
resource "aws_sfn_state_machine" "migration_workflow" {
  count = var.enable_migration_orchestration ? 1 : 0

  name     = "${var.project_name}-migration-workflow"
  role_arn = aws_iam_role.step_functions[0].arn

  definition = jsonencode({
    Comment = "Migration workflow orchestration"
    StartAt = "PreMigrationValidation"
    States = {
      PreMigrationValidation = {
        Type = "Task"
        Resource = aws_lambda_function.migration_validator[0].arn
        Next = "MigrationExecution"
      }
      MigrationExecution = {
        Type = "Parallel"
        Branches = [
          {
            StartAt = "DatabaseMigration"
            States = {
              DatabaseMigration = {
                Type = "Task"
                Resource = "arn:aws:states:::dms:startReplicationTask.sync"
                Parameters = {
                  ReplicationTaskArn = aws_dms_replication_task.migration[0].replication_task_arn
                }
                End = true
              }
            }
          },
          {
            StartAt = "ApplicationMigration"
            States = {
              ApplicationMigration = {
                Type = "Task"
                Resource = aws_lambda_function.app_migrator[0].arn
                End = true
              }
            }
          }
        ]
        Next = "PostMigrationValidation"
      }
      PostMigrationValidation = {
        Type = "Task"
        Resource = aws_lambda_function.migration_validator[0].arn
        End = true
      }
    }
  })

  tags = local.domain_tags
}

# DMS Replication Task
resource "aws_dms_replication_task" "migration" {
  count = var.enable_database_migration_service ? 1 : 0

  migration_type                = "full-load-and-cdc"
  replication_instance_arn      = aws_dms_replication_instance.migration[0].replication_instance_arn
  replication_task_id          = "${var.project_name}-migration-task"
  source_endpoint_arn          = aws_dms_endpoint.source[0].endpoint_arn
  target_endpoint_arn          = aws_dms_endpoint.target[0].endpoint_arn
  
  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "1"
        object-locator = {
          schema-name = "%"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  tags = local.domain_tags
}

# Security Groups
resource "aws_security_group" "migration" {
  count = var.enable_application_migration_service ? 1 : 0

  name_prefix = "${var.project_name}-migration-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.domain_tags
}

resource "aws_security_group" "dms" {
  count = var.enable_database_migration_service ? 1 : 0

  name_prefix = "${var.project_name}-dms-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.domain_tags
}

resource "aws_security_group" "aurora" {
  count = var.enable_database_migration_service ? 1 : 0

  name_prefix = "${var.project_name}-aurora-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.enable_database_migration_service ? [aws_security_group.dms[0].id] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.domain_tags
}

resource "aws_security_group" "ecs" {
  count = var.enable_container_migration ? 1 : 0

  name_prefix = "${var.project_name}-ecs-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.domain_tags
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  count = var.enable_database_migration_service ? 1 : 0

  name       = "${var.project_name}-aurora-subnet-group"
  subnet_ids = var.subnet_ids

  tags = local.domain_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs" {
  count = var.enable_container_migration ? 1 : 0

  name              = "/ecs/${var.project_name}-migrated-app"
  retention_in_days = var.log_retention_days

  tags = local.domain_tags
}

# IAM Roles
resource "aws_iam_role" "ecs_execution" {
  count = var.enable_container_migration ? 1 : 0

  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  count = var.enable_container_migration ? 1 : 0

  role       = aws_iam_role.ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  count = var.enable_container_migration ? 1 : 0

  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role" "lambda" {
  count = var.enable_serverless_migration ? 1 : 0

  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count = var.enable_serverless_migration ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "step_functions" {
  count = var.enable_migration_orchestration ? 1 : 0

  name = "${var.project_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.enable_database_migration_service ? 1 : 0

  name = "${var.project_name}-rds-monitoring-role"

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

  tags = local.domain_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.enable_database_migration_service ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}