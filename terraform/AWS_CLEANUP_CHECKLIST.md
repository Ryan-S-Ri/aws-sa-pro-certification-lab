# AWS Resource Cleanup Checklist

## Resources to manually delete in AWS Console:

### 1. EC2 Resources
- [ ] Terminate all EC2 instances
- [ ] Delete all Auto Scaling Groups
- [ ] Delete all Launch Templates
- [ ] Delete all Load Balancers (ALB, NLB)
- [ ] Delete all Target Groups
- [ ] Release all Elastic IPs
- [ ] Delete all Key Pairs
- [ ] Delete all Security Groups (except default)

### 2. VPC Resources
- [ ] Delete all NAT Gateways
- [ ] Delete all Internet Gateways
- [ ] Delete all Route Tables (except main)
- [ ] Delete all Subnets
- [ ] Delete all VPCs (except default)
- [ ] Delete all VPC Peering Connections

### 3. RDS/Database Resources
- [ ] Delete all RDS clusters and instances
- [ ] Delete all DB Subnet Groups
- [ ] Delete all DB Parameter Groups
- [ ] Delete all ElastiCache clusters
- [ ] Delete all ElastiCache Subnet Groups
- [ ] Delete all DynamoDB tables

### 4. Serverless Resources
- [ ] Delete all Lambda functions
- [ ] Delete all Lambda layers
- [ ] Delete all API Gateways (REST and HTTP)
- [ ] Delete all Step Functions
- [ ] Delete all EventBridge rules
- [ ] Delete all SQS queues
- [ ] Delete all SNS topics

### 5. Storage Resources
- [ ] Empty and delete all S3 buckets
- [ ] Delete all EFS file systems

### 6. Monitoring Resources
- [ ] Delete all CloudWatch Dashboards
- [ ] Delete all CloudWatch Alarms
- [ ] Delete all CloudWatch Log Groups
- [ ] Delete all SNS subscriptions

### 7. Security Resources
- [ ] Delete all Secrets in Secrets Manager
- [ ] Delete all KMS keys (schedule deletion)
- [ ] Delete all IAM roles (except AWS service-linked)
- [ ] Delete all IAM policies (except AWS managed)

## Order of Deletion:
1. Start with compute resources (EC2, Lambda)
2. Then databases and storage
3. Then networking (VPC last)
4. Finally security resources

## Tips:
- Check all regions if you deployed in multiple regions
- Some resources may have dependencies - delete in order
- KMS keys require scheduling deletion (7-30 days)
- Check AWS Cost Explorer tomorrow to ensure all resources are gone
