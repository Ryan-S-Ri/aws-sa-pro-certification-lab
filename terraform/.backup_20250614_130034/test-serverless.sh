#!/bin/bash

# test-serverless.sh - Test script for Serverless & API infrastructure
# This script tests Lambda functions, API Gateway, SQS, SNS, and Step Functions

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get infrastructure details from Terraform output
echo -e "${BLUE}=== Serverless Infrastructure Test ===${NC}"
echo -e "${BLUE}Getting infrastructure details...${NC}"

# Parse Terraform outputs
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
HTTP_API_URL=$(terraform output -raw http_api_url 2>/dev/null || echo "")
LAMBDA_FUNCTIONS=$(terraform output -json lambda_function_names 2>/dev/null || echo "{}")
SQS_QUEUES=$(terraform output -json sqs_queue_urls 2>/dev/null || echo "{}")
STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn 2>/dev/null || echo "")

# Extract specific values
API_HANDLER=$(echo $LAMBDA_FUNCTIONS | jq -r '.api_handler // empty')
EVENT_PROCESSOR=$(echo $LAMBDA_FUNCTIONS | jq -r '.event_processor // empty')
SCHEDULED_TASK=$(echo $LAMBDA_FUNCTIONS | jq -r '.scheduled_task // empty')
PROCESSING_QUEUE=$(echo $SQS_QUEUES | jq -r '.processing_queue // empty')

# ================================================================
# TEST LAMBDA FUNCTIONS
# ================================================================

echo -e "\n${YELLOW}Testing Lambda Functions...${NC}"

# Test API Handler
if [ -n "$API_HANDLER" ]; then
    echo -e "${BLUE}Testing API Handler Lambda...${NC}"
    
    # Create test payload
    TEST_PAYLOAD=$(cat <<EOF
{
  "httpMethod": "GET",
  "path": "/items",
  "headers": {
    "Content-Type": "application/json"
  }
}
EOF
)
    
    # Invoke Lambda
    aws lambda invoke \
        --function-name "$API_HANDLER" \
        --payload "$(echo $TEST_PAYLOAD | base64)" \
        --cli-binary-format raw-in-base64-out \
        response.json
    
    # Check response
    if [ -f response.json ]; then
        echo -e "${GREEN}✓ API Handler Lambda invoked successfully${NC}"
        cat response.json | jq .
        rm response.json
    else
        echo -e "${RED}✗ Failed to invoke API Handler Lambda${NC}"
    fi
else
    echo -e "${YELLOW}⚠ API Handler Lambda not found${NC}"
fi

# Test Event Processor
if [ -n "$EVENT_PROCESSOR" ]; then
    echo -e "\n${BLUE}Testing Event Processor Lambda...${NC}"
    
    # Create test event
    TEST_EVENT=$(cat <<EOF
{
  "action": "test",
  "message": "Test event from test script",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    # Invoke Lambda
    aws lambda invoke \
        --function-name "$EVENT_PROCESSOR" \
        --payload "$(echo $TEST_EVENT | base64)" \
        --cli-binary-format raw-in-base64-out \
        response.json
    
    if [ -f response.json ]; then
        echo -e "${GREEN}✓ Event Processor Lambda invoked successfully${NC}"
        cat response.json | jq .
        rm response.json
    else
        echo -e "${RED}✗ Failed to invoke Event Processor Lambda${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Event Processor Lambda not found${NC}"
fi

# ================================================================
# TEST API GATEWAY
# ================================================================

echo -e "\n${YELLOW}Testing API Gateway...${NC}"

# Test REST API
if [ -n "$API_URL" ] && [ "$API_URL" != "API Gateway not enabled" ]; then
    echo -e "${BLUE}Testing REST API Gateway...${NC}"
    
    # Test GET /items
    echo -e "Testing GET ${API_URL}/items"
    RESPONSE=$(curl -s -X GET "${API_URL}/items" || echo "Failed")
    
    if [[ "$RESPONSE" != "Failed" ]]; then
        echo -e "${GREEN}✓ REST API GET request successful${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    else
        echo -e "${RED}✗ REST API GET request failed${NC}"
    fi
    
    # Test POST /items
    echo -e "\nTesting POST ${API_URL}/items"
    POST_DATA='{"name":"Test Item","description":"Created by test script"}'
    RESPONSE=$(curl -s -X POST "${API_URL}/items" \
        -H "Content-Type: application/json" \
        -d "$POST_DATA" || echo "Failed")
    
    if [[ "$RESPONSE" != "Failed" ]]; then
        echo -e "${GREEN}✓ REST API POST request successful${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    else
        echo -e "${RED}✗ REST API POST request failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ REST API Gateway not enabled${NC}"
fi

# Test HTTP API
if [ -n "$HTTP_API_URL" ] && [ "$HTTP_API_URL" != "HTTP API not enabled" ]; then
    echo -e "\n${BLUE}Testing HTTP API Gateway...${NC}"
    
    echo -e "Testing GET ${HTTP_API_URL}/items"
    RESPONSE=$(curl -s -X GET "${HTTP_API_URL}/items" || echo "Failed")
    
    if [[ "$RESPONSE" != "Failed" ]]; then
        echo -e "${GREEN}✓ HTTP API request successful${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    else
        echo -e "${RED}✗ HTTP API request failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ HTTP API Gateway not enabled${NC}"
fi

# ================================================================
# TEST SQS
# ================================================================

echo -e "\n${YELLOW}Testing SQS Queues...${NC}"

if [ -n "$PROCESSING_QUEUE" ]; then
    echo -e "${BLUE}Testing SQS message flow...${NC}"
    
    # Send test message
    MESSAGE_BODY='{"test": true, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "source": "test-script"}'
    
    aws sqs send-message \
        --queue-url "$PROCESSING_QUEUE" \
        --message-body "$MESSAGE_BODY" \
        --message-attributes '{"TestType":{"StringValue":"Integration","DataType":"String"}}' \
        > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Message sent to SQS queue${NC}"
        
        # Check queue attributes
        ATTRIBUTES=$(aws sqs get-queue-attributes \
            --queue-url "$PROCESSING_QUEUE" \
            --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible)
        
        echo "Queue status:"
        echo "$ATTRIBUTES" | jq .
    else
        echo -e "${RED}✗ Failed to send message to SQS${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SQS Processing Queue not found${NC}"
fi

# ================================================================
# TEST STEP FUNCTIONS
# ================================================================

echo -e "\n${YELLOW}Testing Step Functions...${NC}"

if [ -n "$STEP_FUNCTION_ARN" ] && [ "$STEP_FUNCTION_ARN" != "Step Functions not enabled" ]; then
    echo -e "${BLUE}Testing Step Functions state machine...${NC}"
    
    # Start execution
    EXECUTION_NAME="test-execution-$(date +%s)"
    INPUT='{"status": "success", "test": true}'
    
    EXECUTION_ARN=$(aws stepfunctions start-execution \
        --state-machine-arn "$STEP_FUNCTION_ARN" \
        --name "$EXECUTION_NAME" \
        --input "$INPUT" \
        --query 'executionArn' \
        --output text)
    
    if [ -n "$EXECUTION_ARN" ]; then
        echo -e "${GREEN}✓ Step Function execution started${NC}"
        echo "Execution ARN: $EXECUTION_ARN"
        
        # Wait a moment for execution
        sleep 5
        
        # Check execution status
        STATUS=$(aws stepfunctions describe-execution \
            --execution-arn "$EXECUTION_ARN" \
            --query 'status' \
            --output text)
        
        echo "Execution status: $STATUS"
        
        if [ "$STATUS" == "SUCCEEDED" ]; then
            echo -e "${GREEN}✓ Step Function execution completed successfully${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to start Step Function execution${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Step Functions not enabled${NC}"
fi

# ================================================================
# TEST EVENTBRIDGE
# ================================================================

echo -e "\n${YELLOW}Testing EventBridge...${NC}"

# Check if scheduled rule exists
RULE_NAME="${COMMON_NAME}-scheduled-rule"
RULE_EXISTS=$(aws events describe-rule --name "$RULE_NAME" 2>/dev/null || echo "")

if [ -n "$RULE_EXISTS" ]; then
    echo -e "${GREEN}✓ EventBridge scheduled rule exists${NC}"
    echo "$RULE_EXISTS" | jq '{Name: .Name, State: .State, ScheduleExpression: .ScheduleExpression}'
else
    echo -e "${YELLOW}⚠ EventBridge scheduled rule not found${NC}"
fi

# ================================================================
# SUMMARY
# ================================================================

echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}Tests completed!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Check CloudWatch Logs for Lambda execution details"
echo -e "2. Monitor SQS queue for message processing"
echo -e "3. Review Step Functions execution history"
echo -e "4. Verify EventBridge rule triggers"

# ================================================================
# CLEANUP FUNCTION
# ================================================================

cleanup() {
    echo -e "\n${YELLOW}Cleaning up test resources...${NC}"
    
    # Purge test messages from SQS if needed
    if [ -n "$PROCESSING_QUEUE" ]; then
        echo "To purge test messages from SQS queue, run:"
        echo "aws sqs purge-queue --queue-url $PROCESSING_QUEUE"
    fi
}

# Uncomment to enable cleanup on exit
# trap cleanup EXIT

echo -e "\n${GREEN}Test script completed!${NC}"
