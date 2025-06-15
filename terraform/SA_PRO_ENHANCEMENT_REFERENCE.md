# SA Pro Enhancement Reference

## New Domains Added

### Domain 5: Enterprise Architecture (26% of exam)
- **Location:** `domains/domain5-enterprise-architecture/`
- **Focus:** Multi-account strategies, governance, security at scale
- **Key Services:** Organizations, SSO, RAM, Control Tower, Transit Gateway

### Domain 6: Advanced Migration (20% of exam)  
- **Location:** `domains/domain6-advanced-migration/`
- **Focus:** Migration strategies, containerization, modernization
- **Key Services:** MGN, DMS, ECS, Lambda, Step Functions, Aurora

## Study Configurations

### Individual Domain Testing
```bash
# Test Enterprise Architecture
terraform plan -var-file="study-configs/sa-pro-enterprise.tfvars"

# Test Advanced Migration
terraform plan -var-file="study-configs/sa-pro-migration.tfvars"
```

### Comprehensive SA Pro Testing
```bash
# Test all domains together
terraform plan -var-file="study-configs/sa-pro-comprehensive.tfvars"
```

## Key Variables Added

### Domain 5 Variables
- `enable_domain5` - Master toggle for Domain 5
- `enable_organizations` - AWS Organizations setup
- `enable_enterprise_transit_gateway` - Enterprise networking
- `enable_security_hub_enterprise` - Centralized security

### Domain 6 Variables  
- `enable_domain6` - Master toggle for Domain 6
- `enable_application_migration_service` - MGN migration
- `enable_database_migration_service` - DMS migration
- `enable_container_migration` - ECS containerization
- `enable_serverless_migration` - Lambda patterns

## Exam Alignment

Your lab now covers all SA Professional exam domains:
1. ✅ Design Solutions for Organizational Complexity (26%) - Domain 5
2. ✅ Design for New Solutions (29%) - Domain 2 + enhancements
3. ✅ Continuous Improvement (25%) - Domain 3 + enhancements  
4. ✅ Migration and Modernization (20%) - Domain 6

## Next Steps

1. Run validation: `./validate_sa_pro_enhancement.sh`
2. Test individual domains with study configs
3. Practice with comprehensive configuration
4. Review exercises in each domain
5. Study the README files for exam tips

## Cost Considerations

- Domain 5: Organizations (free), Transit Gateway ($36/month), Config aggregator ($2/month)
- Domain 6: DMS instance ($14/month), Aurora ($29/month), ECS Fargate (pay per use)
- Always destroy resources after studying to minimize costs
