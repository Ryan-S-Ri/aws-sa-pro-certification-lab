# Domain Outputs

After deploying this domain, you can access the following outputs:

```bash
# List all outputs
terraform output

# Get specific output value
terraform output -raw <output_name>
```

## Available Outputs
Check the outputs.tf file in the domain directory for all available outputs.

## Using Outputs in Exercises
Many exercises reference these outputs. For example:
- Resource IDs for AWS CLI commands
- Endpoints for testing
- ARNs for cross-service integration
