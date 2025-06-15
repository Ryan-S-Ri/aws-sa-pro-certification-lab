# Exercise 1: Microservices Deployment

## Objective
Deploy a microservices architecture using API Gateway and Lambda functions.

## Prerequisites
- Domain 2 infrastructure deployed
- Lambda functions ready
- API Gateway configured

## Duration
45 minutes

## Tasks

### Task 1: Deploy Lambda Function
```bash
# Create deployment package
cd lambda
zip function.zip index.py
aws lambda update-function-code \
  --function-name $(terraform output -raw lambda_function_name) \
  --zip-file fileb://function.zip
```

### Task 2: Configure API Gateway
1. Create REST API resources
2. Configure Lambda integration
3. Deploy API stage

```bash
# Get API Gateway ID
API_ID=$(terraform output -raw api_gateway_id)

# Create resource
aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $(aws apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text) \
  --path-part "users"
```

### Task 3: Test Microservice
```bash
# Get invoke URL
INVOKE_URL=$(aws apigateway get-stages \
  --rest-api-id $API_ID \
  --query 'item[0].invokeUrl' \
  --output text)

# Test endpoint
curl -X GET $INVOKE_URL/users
```

## Validation
- Lambda function executes successfully
- API Gateway returns proper responses
- CloudWatch logs show execution details
