# Main configuration file
# This file orchestrates all the modules

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Local values
locals {
  environment = terraform.workspace == "default" ? "dev" : terraform.workspace
  name_prefix = "${var.project_name}-${local.environment}"
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  count  = var.enable_networking ? 1 : 0
  
  project_name       = var.project_name
  environment        = local.environment
  common_tags        = var.common_tags
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
}

# Security Module
module "security" {
  source = "./modules/security"
  count  = var.enable_security ? 1 : 0
  
  project_name       = var.project_name
  environment        = local.environment
  common_tags        = var.common_tags
  vpc_id            = var.enable_networking ? module.networking[0].vpc_id : ""
  enable_web_sg     = var.enable_web_sg
  enable_database_sg = var.enable_database_sg
}

# Compute Module
module "compute" {
  source = "./modules/compute"
  count  = var.enable_compute ? 1 : 0
  
  project_name = var.project_name
  environment  = local.environment
  common_tags  = var.common_tags
  vpc_id       = var.enable_networking ? module.networking[0].vpc_id : ""
  subnet_ids   = var.enable_networking ? module.networking[0].private_subnet_ids : []
}

# Database Module
module "database" {
  source = "./modules/database"
  count  = var.enable_database ? 1 : 0
  
  project_name = var.project_name
  environment  = local.environment
  common_tags  = var.common_tags
  vpc_id       = var.enable_networking ? module.networking[0].vpc_id : ""
  subnet_ids   = var.enable_networking ? module.networking[0].private_subnet_ids : []
}

# Storage Module
module "storage" {
  source = "./modules/storage"
  count  = var.enable_storage ? 1 : 0
  
  project_name      = var.project_name
  environment       = local.environment
  common_tags       = var.common_tags
  bucket_prefix     = local.name_prefix
  enable_versioning = var.enable_versioning
  enable_encryption = var.enable_encryption
}

# Serverless Module
module "serverless" {
  source = "./modules/serverless"
  count  = var.enable_serverless ? 1 : 0
  
  project_name = var.project_name
  environment  = local.environment
  common_tags  = var.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0
  
  project_name               = var.project_name
  environment                = local.environment
  common_tags                = var.common_tags
  enable_detailed_monitoring = var.enable_detailed_monitoring
  alarm_email               = var.alarm_email
}
