# Compute Module

This module manages compute resources.

## Usage

```hcl
module "compute" {
  source = "./modules/compute"
  
  project_name = var.project_name
  environment  = local.environment
  common_tags  = var.common_tags
  
  # Add other required variables
}
```

## Resources

Check `main.tf` for the complete list of resources managed by this module.

## Variables

See `variables.tf` for all available variables.

## Outputs

See `outputs.tf` for all available outputs.
