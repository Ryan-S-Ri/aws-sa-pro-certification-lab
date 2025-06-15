# Basic security group for serverless resources
resource "aws_security_group" "lambda" {
  provider    = aws.primary
  name        = "${var.common_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.primary.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-lambda-sg"
  })
}

# Basic secrets in Secrets Manager (only if enabled)
resource "aws_secretsmanager_secret" "db_password" {
  count                   = var.enable_secrets_manager ? 1 : 0
  provider                = aws.primary
  name                    = "${var.common_name}-db-password"
  description             = "Database password for ${var.common_name}"
  recovery_window_in_days = 0  # Immediate deletion for lab
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-db-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count     = var.enable_secrets_manager ? 1 : 0
  provider  = aws.primary
  secret_id = aws_secretsmanager_secret.db_password[0].id
  secret_string = jsonencode({
    username = var.mysql_master_username
    password = var.mysql_master_password
  })
}
