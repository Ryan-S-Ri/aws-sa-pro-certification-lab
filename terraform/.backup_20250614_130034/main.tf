terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Primary AWS Provider - SA Pro labs
provider "aws" {
  alias  = "primary"
  region = "us-east-1"  # Changed from var.primary_region for consistency
  
  default_tags {
    tags = var.common_tags
  }
}

# Testbed AWS Provider - DR and testing
provider "aws" {
  alias  = "testbed"
  region = "us-east-2"  # Changed from var.testbed_region for consistency
  
  default_tags {
    tags = var.common_tags
  }
}

# Networking AWS Provider - Advanced networking scenarios
provider "aws" {
  alias  = "networking" 
  region = "us-west-1"  # Keep as us-west-1
  
  default_tags {
    tags = var.common_tags
  }
}
