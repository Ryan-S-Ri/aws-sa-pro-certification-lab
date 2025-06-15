# AWS SA Pro Lab - Main Orchestrator
# This file orchestrates the deployment of domain-specific infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider Configuration
provider "aws" {
  region = var.primary_region
  
  default_tags {
    tags = merge(
      var.common_tags,
      {
        Environment = var.environment
        Project     = "aws-sa-pro-lab"
      }
    )
  }
}

# Provider for DR region
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  
  default_tags {
    tags = merge(
      var.common_tags,
      {
        Environment = var.environment
        Project     = "aws-sa-pro-lab"
        Region      = "dr"
      }
    )
  }
}

# Shared Infrastructure
module "shared_infrastructure" {
  source = "./shared-infrastructure"
  count  = var.enable_shared_infrastructure ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  primary_region  = var.primary_region
  dr_region      = var.dr_region
  common_tags    = var.common_tags
}

# Domain 1: Organizational Complexity
module "domain1" {
  source = "./domains/domain1-organizational-complexity"
  count  = var.enable_domain1 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies from shared infrastructure
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids      = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []
}

# Domain 2: New Solutions
module "domain2" {
  source = "./domains/domain2-new-solutions"
  count  = var.enable_domain2 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids      = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []
}

# Domain 3: Continuous Improvement
module "domain3" {
  source = "./domains/domain3-continuous-improvement"
  count  = var.enable_domain3 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
}

# Domain 4: Migration and Modernization
module "domain4" {
  source = "./domains/domain4-migration-modernization"
  count  = var.enable_domain4 ? 1 : 0
  
  project_name    = var.project_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  # Dependencies
  vpc_id          = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids      = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []
}

# Domain 5: Enterprise Architecture
module "domain5" {
  source = "./domains/domain5-enterprise-architecture"
  count  = var.enable_domain5 ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags

  # Enterprise Architecture specific variables from compatibility layer
  enable_organizations                = var.enable_organizations
  enable_security_control_policies    = var.enable_security_control_policies
  enable_cross_account_roles         = var.enable_cross_account_roles
  trusted_account_ids               = var.trusted_account_ids
  external_id                       = var.external_id
  enable_enterprise_sso             = var.enable_enterprise_sso
  enable_config_aggregator          = var.enable_config_aggregator
  enable_security_hub_enterprise    = var.enable_security_hub_enterprise
  enable_guardduty_enterprise       = var.enable_guardduty_enterprise
  enable_enterprise_transit_gateway = var.enable_enterprise_transit_gateway
  enable_ram_sharing                = var.enable_ram_sharing
  enable_enterprise_budgets         = var.enable_enterprise_budgets
  notification_email                = var.notification_email
}

# Domain 6: Advanced Migration and Modernization
module "domain6" {
  source = "./domains/domain6-advanced-migration"
  count  = var.enable_domain6 ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags

  # Dependencies
  vpc_id     = var.enable_shared_infrastructure ? module.shared_infrastructure[0].vpc_id : ""
  subnet_ids = var.enable_shared_infrastructure ? module.shared_infrastructure[0].private_subnet_ids : []

  # Migration specific variables from compatibility layer
  enable_application_migration_service = var.enable_application_migration_service
  enable_database_migration_service   = var.enable_database_migration_service
  enable_container_migration          = var.enable_container_migration
  enable_serverless_migration         = var.enable_serverless_migration
  enable_migration_orchestration      = var.enable_migration_orchestration
}
