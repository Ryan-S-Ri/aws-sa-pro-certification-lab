# Exercise 2: Enterprise Networking with Transit Gateway

## Objective
Implement enterprise-scale networking using Transit Gateway and Resource Access Manager.

## Scenario
Design a hub-and-spoke network architecture that can scale across multiple accounts and regions while providing centralized connectivity management.

## Tasks

### 1. Transit Gateway Deployment
- Deploy Transit Gateway in hub account
- Configure route tables and associations
- Set up VPC attachments

### 2. Resource Sharing with RAM
- Share Transit Gateway using Resource Access Manager
- Configure cross-account sharing
- Set up resource associations

### 3. Routing Strategy
- Design routing for different environments
- Implement security groups for inter-VPC communication
- Configure route propagation

### 4. Monitoring and Troubleshooting
- Set up VPC Flow Logs
- Configure CloudWatch metrics
- Implement network monitoring

## Architecture Patterns
- Hub-and-spoke topology
- Shared services architecture
- Network segmentation strategies
- Cross-account networking

## Validation
1. Test connectivity between VPCs
2. Verify route table configurations
3. Check RAM sharing status
4. Monitor traffic flows

## Cost Considerations
- Transit Gateway attachment costs
- Data processing charges
- Cross-AZ traffic costs
