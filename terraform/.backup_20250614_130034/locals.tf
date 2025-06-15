locals {
  common_name = var.common_name
  account_id  = data.aws_caller_identity.current.account_id
  region      = var.primary_region
  
  # SA Pro Exam - Multi-region setup
  vpc_cidrs = {
    primary    = "10.0.0.0/16"    # us-east-1 (SA Pro primary)
    testbed    = "10.1.0.0/16"    # us-east-2 (your CLI default)
    networking = "10.2.0.0/16"    # us-west-1 (advanced networking)
  }
  
  azs = {
    primary    = ["us-east-1a", "us-east-1b", "us-east-1c"]      # SA Pro primary
    testbed    = ["us-east-2a", "us-east-2b", "us-east-2c"]      # Your CLI default
    networking = ["us-west-1a", "us-west-1c"]                    # us-west-1 only has 2 AZs
  }

  # Environment configuration
  env_config = {
    dev = {
      stage_name = "dev"
      api_name   = "dev-api"
    }
    staging = {
      stage_name = "staging"
      api_name   = "staging-api"
    }
    prod = {
      stage_name = "prod"
      api_name   = "prod-api"
    }
  }
}

data "aws_caller_identity" "current" {
  provider = aws.primary
}
