terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider (without alias)
provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Terraform = "true"
      Action    = "destroy"
    }
  }
}

# Primary provider (with alias) - THIS IS WHAT YOUR STATE EXPECTS
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
  
  default_tags {
    tags = {
      Terraform = "true"
      Action    = "destroy"
    }
  }
}

# Minimal module configurations just for destroy
# We set count = 0 to destroy everything

module "networking" {
  source = "./modules/networking"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "security" {
  source = "./modules/security"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "compute" {
  source = "./modules/compute"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "database" {
  source = "./modules/database"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "storage" {
  source = "./modules/storage"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "serverless" {
  source = "./modules/serverless"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = 0
  providers = {
    aws = aws.primary
  }
}

# Add minimal variables to suppress warnings
variable "project_name" {
  default = "dummy"
}

variable "environment" {
  default = "dummy"
}

variable "common_tags" {
  default = {}
}

variable "vpc_id" {
  default = ""
}

variable "subnet_ids" {
  default = []
}

variable "aws_region" {
  default = "us-east-1"
}
