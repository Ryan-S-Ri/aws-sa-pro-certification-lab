# Domain 5: Enterprise Architecture
# Covers: Multi-account strategies, AWS Organizations, governance, security at scale

# Local variables for this domain
locals {
  domain_name = "domain5-enterprise-architecture"
  domain_tags = merge(var.common_tags, {
    Domain = "Enterprise Architecture"
    ExamDomain = "Domain5"
  })
}

# AWS Organizations (simulated for single account)
resource "aws_organizations_organization" "main" {
  count = var.enable_organizations ? 1 : 0
  
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com"
  ]

  feature_set = "ALL"
  
  # Note: aws_organizations_organization doesn't support tags directly
}

# Service Control Policy (SCP) - Example restrictive policy
resource "aws_organizations_policy" "security_baseline" {
  count = var.enable_organizations && var.enable_security_control_policies ? 1 : 0
  
  name        = "${var.project_name}-security-baseline-scp"
  description = "Security baseline SCP for organizational units"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDeleteCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDisableGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:StopMonitoringMembers"
        ]
        Resource = "*"
      },
      {
        Sid    = "RequireMFAForSensitiveActions"
        Effect = "Deny"
        Action = [
          "iam:DeleteRole",
          "iam:DeleteUser",
          "iam:PutUserPolicy",
          "iam:AttachUserPolicy"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = local.domain_tags
}

# Cross-Account Roles for Enterprise Access
resource "aws_iam_role" "cross_account_admin" {
  count = var.enable_cross_account_roles ? 1 : 0
  
  name = "${var.project_name}-cross-account-admin"
  path = "/enterprise/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_ids
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role_policy_attachment" "cross_account_admin" {
  count = var.enable_cross_account_roles ? 1 : 0
  
  role       = aws_iam_role.cross_account_admin[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Cross-Account Read-Only Role
resource "aws_iam_role" "cross_account_readonly" {
  count = var.enable_cross_account_roles ? 1 : 0
  
  name = "${var.project_name}-cross-account-readonly"
  path = "/enterprise/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_ids
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role_policy_attachment" "cross_account_readonly" {
  count = var.enable_cross_account_roles ? 1 : 0
  
  role       = aws_iam_role.cross_account_readonly[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Enterprise SSO Configuration (AWS IAM Identity Center simulation)
resource "aws_iam_saml_provider" "enterprise_sso" {
  count = var.enable_enterprise_sso ? 1 : 0
  
  name                   = "${var.project_name}-enterprise-sso"
  saml_metadata_document = var.saml_metadata_document

  tags = local.domain_tags
}

# Enterprise governance - Config aggregator
resource "aws_config_configuration_aggregator" "enterprise" {
  count = var.enable_config_aggregator ? 1 : 0
  
  name = "${var.project_name}-enterprise-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator[0].arn
  }

  tags = local.domain_tags
}

# IAM role for Config aggregator
resource "aws_iam_role" "config_aggregator" {
  count = var.enable_config_aggregator ? 1 : 0
  
  name = "${var.project_name}-config-aggregator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = local.domain_tags
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  count = var.enable_config_aggregator ? 1 : 0
  
  role       = aws_iam_role.config_aggregator[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Enterprise Security Hub - Central security findings
resource "aws_securityhub_account" "enterprise" {
  count = var.enable_security_hub_enterprise ? 1 : 0

  enable_default_standards = true
  control_finding_generator = "SECURITY_CONTROL"
  
  # Note: aws_securityhub_account doesn't support tags directly
}

# GuardDuty Master Account Configuration
resource "aws_guardduty_detector" "enterprise" {
  count = var.enable_guardduty_enterprise ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = local.domain_tags
}

# Enterprise Transit Gateway for multi-account networking
resource "aws_ec2_transit_gateway" "enterprise" {
  count = var.enable_enterprise_transit_gateway ? 1 : 0

  description                     = "${var.project_name} Enterprise Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"
  
  tags = merge(local.domain_tags, {
    Name = "${var.project_name}-enterprise-tgw"
  })
}

# RAM (Resource Access Manager) for cross-account sharing
resource "aws_ram_resource_share" "enterprise_tgw" {
  count = var.enable_enterprise_transit_gateway && var.enable_ram_sharing ? 1 : 0

  name                      = "${var.project_name}-tgw-share"
  allow_external_principals = false

  tags = local.domain_tags
}

resource "aws_ram_resource_association" "enterprise_tgw" {
  count = var.enable_enterprise_transit_gateway && var.enable_ram_sharing ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.enterprise[0].arn
  resource_share_arn = aws_ram_resource_share.enterprise_tgw[0].arn
}

# Enterprise Cost Management - Consolidated billing insights
resource "aws_budgets_budget" "enterprise_master" {
  count = var.enable_enterprise_budgets ? 1 : 0

  name         = "${var.project_name}-enterprise-budget"
  budget_type  = "COST"
  limit_amount = var.enterprise_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = var.monitored_account_ids
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = [var.notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]
  }

  tags = local.domain_tags
}

# Enterprise tagging compliance (using data source instead of invalid resource)
data "aws_resourcegroupstaggingapi_resources" "enterprise_compliance" {
  count = var.enable_tagging_compliance ? 1 : 0

  resource_type_filters = ["AWS::EC2::Instance", "AWS::RDS::DBInstance", "AWS::S3::Bucket"]
  
  tag_filter {
    key    = "Environment"
    values = [var.environment]
  }
  
  tag_filter {
    key    = "Project"
    values = [var.project_name]
  }
}