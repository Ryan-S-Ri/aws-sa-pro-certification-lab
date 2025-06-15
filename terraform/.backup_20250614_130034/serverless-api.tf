# serverless-api.tf - Serverless & API Infrastructure for SA-Pro Lab
# Implements Lambda, API Gateway, Step Functions, EventBridge, SQS/SNS

# ================================================================
# LAMBDA LAYER FOR SHARED DEPENDENCIES
# ================================================================

resource "aws_lambda_layer_version" "common_libs" {
  count                    = var.enable_serverless_tier ? 1 : 0
  provider                 = aws.primary
  filename                 = "lambda-layers/common-libs.zip"
  layer_name              = "${local.common_name}-common-libs"
  description             = "Common libraries for Lambda functions"
  compatible_runtimes     = ["python3.9", "python3.10", "python3.11"]
  compatible_architectures = ["x86_64", "arm64"]

  # Note: You'll need to create this zip file with common dependencies
  # For now, we'll use a placeholder
  source_code_hash = filebase64sha256("lambda-layers/common-libs.zip")
  
  lifecycle {
    ignore_changes = [source_code_hash]
  }
}

# ================================================================
# LAMBDA EXECUTION ROLE
# ================================================================

resource "aws_iam_role" "lambda_execution" {
  count    = var.enable_serverless_tier ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.common_name}-lambda-execution-role"
  }
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.enable_serverless_tier ? 1 : 0
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC access policy
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.enable_serverless_tier ? 1 : 0
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom Lambda policy for accessing other AWS services
resource "aws_iam_role_policy" "lambda_custom" {
  count    = var.enable_serverless_tier ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-lambda-custom-policy"
  role     = aws_iam_role.lambda_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.enable_database_tier ? [
          aws_dynamodb_table.lab_table[0].arn,
          "${aws_dynamodb_table.lab_table[0].arn}/index/*"
        ] : ["arn:aws:dynamodb:*:*:table/dummy"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = var.enable_storage_tier ? [
          "${aws_s3_bucket.lambda_artifacts[0].arn}/*"
        ] : ["arn:aws:s3:::dummy/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.processing_queue[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.notifications[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# ================================================================
# LAMBDA FUNCTIONS
# ================================================================

# 1. API Handler Function
resource "aws_lambda_function" "api_handler" {
  count            = var.enable_serverless_tier ? 1 : 0
  provider         = aws.primary
  filename         = "lambda-functions/api-handler.zip"
  function_name    = "${local.common_name}-api-handler"
  role            = aws_iam_role.lambda_execution[0].arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("lambda-functions/api-handler.zip")
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      TABLE_NAME = var.enable_database_tier ? aws_dynamodb_table.lab_table[0].name : "dummy-table"
      REGION     = var.primary_region
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda[0].id]
  }

  layers = [aws_lambda_layer_version.common_libs[0].arn]

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq[0].arn
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name = "${local.common_name}-api-handler"
  }
}

# 2. Event Processor Function
resource "aws_lambda_function" "event_processor" {
  count            = var.enable_serverless_tier ? 1 : 0
  provider         = aws.primary
  filename         = "lambda-functions/event-processor.zip"
  function_name    = "${local.common_name}-event-processor"
  role            = aws_iam_role.lambda_execution[0].arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("lambda-functions/event-processor.zip")
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512
  reserved_concurrent_executions = 10

  environment {
    variables = {
      QUEUE_URL  = aws_sqs_queue.processing_queue[0].url
      SNS_TOPIC  = aws_sns_topic.notifications[0].arn
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name = "${local.common_name}-event-processor"
  }
}

# 3. Scheduled Task Function
resource "aws_lambda_function" "scheduled_task" {
  count            = var.enable_serverless_tier ? 1 : 0
  provider         = aws.primary
  filename         = "lambda-functions/scheduled-task.zip"
  function_name    = "${local.common_name}-scheduled-task"
  role            = aws_iam_role.lambda_execution[0].arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("lambda-functions/scheduled-task.zip")
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = 128

  environment {
    variables = {
      ENVIRONMENT = var.common_tags.Environment
    }
  }

  lifecycle {
    ignore_changes = [source_code_hash]
  }

  tags = {
    Name = "${local.common_name}-scheduled-task"
  }
}

# ================================================================
# LAMBDA SECURITY GROUP
# ================================================================

resource "aws_security_group" "lambda" {
  count       = var.enable_serverless_tier ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.primary.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-lambda-sg"
  }
}

# ================================================================
# API GATEWAY REST API
# ================================================================

resource "aws_api_gateway_rest_api" "main" {
  count       = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider    = aws.primary
  name        = "${local.common_name}-api"
  description = "Main REST API for the lab"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${local.common_name}-api"
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "items" {
  count       = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider    = aws.primary
  rest_api_id = aws_api_gateway_rest_api.main[0].id
  parent_id   = aws_api_gateway_rest_api.main[0].root_resource_id
  path_part   = "items"
}

# API Gateway Method
resource "aws_api_gateway_method" "get_items" {
  count         = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider      = aws.primary
  rest_api_id   = aws_api_gateway_rest_api.main[0].id
  resource_id   = aws_api_gateway_resource.items[0].id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "lambda" {
  count                   = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider                = aws.primary
  rest_api_id             = aws_api_gateway_rest_api.main[0].id
  resource_id             = aws_api_gateway_resource.items[0].id
  http_method             = aws_api_gateway_method.get_items[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler[0].invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  count       = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider    = aws.primary
  rest_api_id = aws_api_gateway_rest_api.main[0].id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.items[0].id,
      aws_api_gateway_method.get_items[0].id,
      aws_api_gateway_integration.lambda[0].id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  count         = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider      = aws.primary
  deployment_id = aws_api_gateway_deployment.main[0].id
  rest_api_id   = aws_api_gateway_rest_api.main[0].id
  stage_name    = var.common_tags.Environment

  xray_tracing_enabled = var.enable_xray

  tags = {
    Name = "${local.common_name}-api-stage"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  count         = var.enable_serverless_tier && var.enable_api_gateway ? 1 : 0
  provider      = aws.primary
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main[0].execution_arn}/*/*"
}

# ================================================================
# SQS QUEUES
# ================================================================

# Processing Queue
resource "aws_sqs_queue" "processing_queue" {
  count                     = var.enable_serverless_tier ? 1 : 0
  provider                  = aws.primary
  name                      = "${local.common_name}-processing-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 20       # Long polling
  visibility_timeout_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${local.common_name}-processing-queue"
  }
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  count                     = var.enable_serverless_tier ? 1 : 0
  provider                  = aws.primary
  name                      = "${local.common_name}-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "${local.common_name}-dlq"
  }
}

# Lambda trigger for SQS
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count            = var.enable_serverless_tier ? 1 : 0
  provider         = aws.primary
  event_source_arn = aws_sqs_queue.processing_queue[0].arn
  function_name    = aws_lambda_function.event_processor[0].arn
  batch_size       = 10
}

# ================================================================
# SNS TOPICS
# ================================================================

resource "aws_sns_topic" "notifications" {
  count    = var.enable_serverless_tier ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-notifications"

  tags = {
    Name = "${local.common_name}-notifications"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.enable_serverless_tier && var.enable_sns_email ? 1 : 0
  provider  = aws.primary
  topic_arn = aws_sns_topic.notifications[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ================================================================
# EVENTBRIDGE (CLOUDWATCH EVENTS)
# ================================================================

# EventBridge Rule for scheduled tasks
resource "aws_cloudwatch_event_rule" "scheduled" {
  count               = var.enable_serverless_tier && var.enable_eventbridge_advanced ? 1 : 0
  provider            = aws.primary
  name                = "${local.common_name}-scheduled-rule"
  description         = "Trigger Lambda function on schedule"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name = "${local.common_name}-scheduled-rule"
  }
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda" {
  count     = var.enable_serverless_tier && var.enable_eventbridge_advanced ? 1 : 0
  provider  = aws.primary
  rule      = aws_cloudwatch_event_rule.scheduled[0].name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.scheduled_task[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "eventbridge" {
  count         = var.enable_serverless_tier && var.enable_eventbridge_advanced ? 1 : 0
  provider      = aws.primary
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled_task[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled[0].arn
}

# Custom EventBridge Bus
resource "aws_cloudwatch_event_bus" "custom" {
  count    = var.enable_serverless_tier && var.enable_eventbridge_advanced ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-custom-bus"

  tags = {
    Name = "${local.common_name}-custom-bus"
  }
}

# ================================================================
# STEP FUNCTIONS
# ================================================================

# Step Functions IAM Role
resource "aws_iam_role" "step_functions" {
  count    = var.enable_serverless_tier && var.enable_step_functions ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.common_name}-step-functions-role"
  }
}

# Step Functions Policy
resource "aws_iam_role_policy" "step_functions" {
  count    = var.enable_serverless_tier && var.enable_step_functions ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-step-functions-policy"
  role     = aws_iam_role.step_functions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.api_handler[0].arn,
          aws_lambda_function.event_processor[0].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.notifications[0].arn
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "workflow" {
  count    = var.enable_serverless_tier && var.enable_step_functions ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-workflow"
  role_arn = aws_iam_role.step_functions[0].arn

  definition = jsonencode({
    Comment = "A sample workflow that orchestrates Lambda functions"
    StartAt = "ProcessInput"
    States = {
      ProcessInput = {
        Type     = "Task"
        Resource = aws_lambda_function.api_handler[0].arn
        Next     = "CheckResult"
      }
      CheckResult = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.status"
            StringEquals  = "success"
            Next          = "NotifySuccess"
          }
        ]
        Default = "NotifyFailure"
      }
      NotifySuccess = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.notifications[0].arn
          Message  = "Workflow completed successfully"
        }
        End = true
      }
      NotifyFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.notifications[0].arn
          Message  = "Workflow failed"
        }
        End = true
      }
    }
  })

  tags = {
    Name = "${local.common_name}-workflow"
  }
}

# ================================================================
# S3 BUCKET FOR LAMBDA ARTIFACTS
# ================================================================

resource "aws_s3_bucket" "lambda_artifacts" {
  count    = var.enable_serverless_tier && var.enable_storage_tier ? 1 : 0
  provider = aws.primary
  bucket   = "${local.common_name}-lambda-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.common_name}-lambda-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  count    = var.enable_serverless_tier && var.enable_storage_tier ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.lambda_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ================================================================
# DYNAMODB STREAMS TRIGGER
# ================================================================

resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  count                  = var.enable_serverless_tier && var.enable_database_tier && var.enable_dynamodb_streams ? 1 : 0
  provider               = aws.primary
  event_source_arn       = aws_dynamodb_table.lab_table[0].stream_arn
  function_name          = aws_lambda_function.event_processor[0].arn
  starting_position      = "LATEST"
  maximum_batching_window_in_seconds = 5
}

# ================================================================
# API GATEWAY HTTP API (Alternative to REST API)
# ================================================================

resource "aws_apigatewayv2_api" "http" {
  count         = var.enable_serverless_tier && var.enable_http_api ? 1 : 0
  provider      = aws.primary
  name          = "${local.common_name}-http-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age          = 300
  }

  tags = {
    Name = "${local.common_name}-http-api"
  }
}

# HTTP API Integration
resource "aws_apigatewayv2_integration" "lambda_http" {
  count              = var.enable_serverless_tier && var.enable_http_api ? 1 : 0
  provider           = aws.primary
  api_id             = aws_apigatewayv2_api.http[0].id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.api_handler[0].invoke_arn
  integration_method = "POST"
}

# HTTP API Route
resource "aws_apigatewayv2_route" "get_items" {
  count     = var.enable_serverless_tier && var.enable_http_api ? 1 : 0
  provider  = aws.primary
  api_id    = aws_apigatewayv2_api.http[0].id
  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_http[0].id}"
}

# HTTP API Stage
resource "aws_apigatewayv2_stage" "default" {
  count       = var.enable_serverless_tier && var.enable_http_api ? 1 : 0
  provider    = aws.primary
  api_id      = aws_apigatewayv2_api.http[0].id
  name        = "default"
  auto_deploy = true
}

# Lambda permission for HTTP API
resource "aws_lambda_permission" "http_api" {
  count         = var.enable_serverless_tier && var.enable_http_api ? 1 : 0
  provider      = aws.primary
  statement_id  = "AllowHTTPAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http[0].execution_arn}/*/*"
}

# ================================================================
# OUTPUTS
# ================================================================

output "api_gateway_url" {
  value = var.enable_serverless_tier && var.enable_api_gateway ? "${aws_api_gateway_stage.main[0].invoke_url}" : "API Gateway not enabled"
  description = "REST API Gateway URL"
}

output "http_api_url" {
  value = var.enable_serverless_tier && var.enable_http_api ? aws_apigatewayv2_stage.default[0].invoke_url : "HTTP API not enabled"
  description = "HTTP API Gateway URL"
}

output "lambda_function_names" {
  value = var.enable_serverless_tier ? {
    api_handler      = aws_lambda_function.api_handler[0].function_name
    event_processor  = aws_lambda_function.event_processor[0].function_name
    scheduled_task   = aws_lambda_function.scheduled_task[0].function_name
  } : {}
  description = "Lambda function names"
}

output "sqs_queue_urls" {
  value = var.enable_serverless_tier ? {
    processing_queue = aws_sqs_queue.processing_queue[0].url
    dlq             = aws_sqs_queue.dlq[0].url
  } : {}
  description = "SQS queue URLs"
}

output "step_function_arn" {
  value = var.enable_serverless_tier && var.enable_step_functions ? aws_sfn_state_machine.workflow[0].arn : "Step Functions not enabled"
  description = "Step Functions state machine ARN"
}
