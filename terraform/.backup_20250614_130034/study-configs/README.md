# AWS Certification Lab - Study Configurations

This directory contains progressive study configurations for AWS certification preparation.

## Configuration Files:

- **domain1-security.tfvars** - Security architecture basics (VPC, IAM, encryption)
- **domain2-resilient.tfvars** - Resilient architectures (Auto Scaling, Load Balancing)
- **domain3-performance.tfvars** - High performance (Databases, caching, CDN)
- **domain4-cost-optimized.tfvars** - Cost optimization (Monitoring, budgets)
- **full-lab.tfvars** - Complete lab setup for final practice

## Usage:

Each configuration builds upon the previous domains:
- Domain 1: Foundation security
- Domain 2: Domain 1 + Resilience features
- Domain 3: Domains 1+2 + Performance features
- Domain 4: Domains 1+2+3 + Cost optimization
- Full Lab: Everything + advanced networking

## Important:

Before using any configuration, update the `notification_email` variable with your actual email address.

## Cost Estimates:

- Domain 1: ~$1-3/day
- Domain 2: ~$3-6/day
- Domain 3: ~$5-10/day
- Domain 4: ~$6-12/day
- Full Lab: ~$15-25/day

Always destroy resources after study sessions to minimize costs!
