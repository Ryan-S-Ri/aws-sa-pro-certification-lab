#!/bin/bash

# setup-lambda-functions.sh - Create Lambda function deployment packages
# This script creates the necessary Lambda function zip files

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Lambda Functions Setup ===${NC}"

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p lambda-functions
mkdir -p lambda-layers/python/lib/python3.9/site-packages

# ================================================================
# API HANDLER FUNCTION
# ================================================================

echo -e "${YELLOW}Creating API Handler function...${NC}"
cat > lambda-functions/api-handler.py << 'EOF'
import json
import boto3
import os
from datetime import datetime

# Initialize AWS services
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'dummy-table')

def handler(event, context):
    """
    Main Lambda handler for API requests
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse the HTTP method
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '/')
        
        if http_method == 'GET' and path == '/items':
            return get_items()
        elif http_method == 'POST' and path == '/items':
            body = json.loads(event.get('body', '{}'))
            return create_item(body)
        elif http_method == 'GET' and path.startswith('/items/'):
            item_id = path.split('/')[-1]
            return get_item(item_id)
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'Not Found'})
            }
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_items():
    """Get all items from DynamoDB"""
    try:
        table = dynamodb.Table(table_name)
        response = table.scan()
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'items': response.get('Items', []),
                'count': response.get('Count', 0)
            })
        }
    except Exception as e:
        print(f"Error getting items: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to get items'})
        }

def create_item(item_data):
    """Create a new item in DynamoDB"""
    try:
        table = dynamodb.Table(table_name)
        
        # Add metadata
        item_data['id'] = item_data.get('id', str(datetime.now().timestamp()))
        item_data['created_at'] = datetime.now().isoformat()
        
        table.put_item(Item=item_data)
        
        return {
            'statusCode': 201,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(item_data)
        }
    except Exception as e:
        print(f"Error creating item: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to create item'})
        }

def get_item(item_id):
    """Get a specific item from DynamoDB"""
    try:
        table = dynamodb.Table(table_name)
        response = table.get_item(Key={'id': item_id})
        
        if 'Item' in response:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(response['Item'])
            }
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'Item not found'})
            }
    except Exception as e:
        print(f"Error getting item: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to get item'})
        }
EOF

# Rename handler file
mv lambda-functions/api-handler.py lambda-functions/index.py

# Create zip file for API handler
cd lambda-functions
zip -r api-handler.zip index.py
rm index.py
cd ..

echo -e "${GREEN}✓ API Handler function created${NC}"

# ================================================================
# EVENT PROCESSOR FUNCTION
# ================================================================

echo -e "${YELLOW}Creating Event Processor function...${NC}"
cat > lambda-functions/event-processor.py << 'EOF'
import json
import boto3
import os
from datetime import datetime

# Initialize AWS services
sqs = boto3.client('sqs')
sns = boto3.client('sns')

queue_url = os.environ.get('QUEUE_URL', '')
sns_topic = os.environ.get('SNS_TOPIC', '')

def handler(event, context):
    """
    Process events from various sources (SQS, DynamoDB Streams, etc.)
    """
    print(f"Processing event: {json.dumps(event)}")
    
    try:
        # Determine event source
        if 'Records' in event:
            for record in event['Records']:
                if 'eventSource' in record:
                    if record['eventSource'] == 'aws:sqs':
                        process_sqs_record(record)
                    elif record['eventSource'] == 'aws:dynamodb':
                        process_dynamodb_record(record)
                    else:
                        print(f"Unknown event source: {record['eventSource']}")
        else:
            # Direct invocation
            process_direct_event(event)
            
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Events processed successfully'})
        }
        
    except Exception as e:
        print(f"Error processing events: {str(e)}")
        # Send notification about failure
        if sns_topic:
            sns.publish(
                TopicArn=sns_topic,
                Subject='Event Processing Failed',
                Message=f'Error: {str(e)}\nEvent: {json.dumps(event)}'
            )
        raise e

def process_sqs_record(record):
    """Process a single SQS record"""
    try:
        body = json.loads(record['body'])
        print(f"Processing SQS message: {body}")
        
        # Add your business logic here
        # Example: Process order, update inventory, etc.
        
        # Simulate processing
        process_data(body)
        
    except Exception as e:
        print(f"Error processing SQS record: {str(e)}")
        raise e

def process_dynamodb_record(record):
    """Process a DynamoDB stream record"""
    try:
        print(f"Processing DynamoDB record: {record['eventName']}")
        
        if record['eventName'] == 'INSERT':
            new_image = record['dynamodb'].get('NewImage', {})
            print(f"New item inserted: {new_image}")
            
            # Example: Send notification for new items
            if sns_topic:
                sns.publish(
                    TopicArn=sns_topic,
                    Subject='New Item Created',
                    Message=f'A new item was created: {json.dumps(new_image)}'
                )
                
        elif record['eventName'] == 'MODIFY':
            old_image = record['dynamodb'].get('OldImage', {})
            new_image = record['dynamodb'].get('NewImage', {})
            print(f"Item modified - Old: {old_image}, New: {new_image}")
            
        elif record['eventName'] == 'REMOVE':
            old_image = record['dynamodb'].get('OldImage', {})
            print(f"Item removed: {old_image}")
            
    except Exception as e:
        print(f"Error processing DynamoDB record: {str(e)}")
        raise e

def process_direct_event(event):
    """Process direct Lambda invocation"""
    print(f"Processing direct invocation: {event}")
    
    # Add your business logic here
    process_data(event)

def process_data(data):
    """Common data processing logic"""
    # Simulate some processing
    print(f"Processing data: {data}")
    
    # Example: Validate data, transform, store, etc.
    if 'action' in data:
        if data['action'] == 'notify':
            if sns_topic:
                sns.publish(
                    TopicArn=sns_topic,
                    Subject='Event Notification',
                    Message=json.dumps(data)
                )
        elif data['action'] == 'queue':
            if queue_url:
                sqs.send_message(
                    QueueUrl=queue_url,
                    MessageBody=json.dumps(data)
                )
    
    print("Data processed successfully")
EOF

# Create zip file for Event Processor
cd lambda-functions
mv event-processor.py index.py
zip -r event-processor.zip index.py
rm index.py
cd ..

echo -e "${GREEN}✓ Event Processor function created${NC}"

# ================================================================
# SCHEDULED TASK FUNCTION
# ================================================================

echo -e "${YELLOW}Creating Scheduled Task function...${NC}"
cat > lambda-functions/scheduled-task.py << 'EOF'
import json
import boto3
import os
from datetime import datetime

# Initialize AWS services
cloudwatch = boto3.client('cloudwatch')
environment = os.environ.get('ENVIRONMENT', 'dev')

def handler(event, context):
    """
    Scheduled task that runs periodically
    """
    print(f"Scheduled task running at: {datetime.now().isoformat()}")
    print(f"Event: {json.dumps(event)}")
    
    try:
        # Perform scheduled tasks
        perform_health_check()
        cleanup_old_data()
        send_metrics()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scheduled task completed successfully',
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error in scheduled task: {str(e)}")
        # Send metric for failed execution
        cloudwatch.put_metric_data(
            Namespace='ScheduledTasks',
            MetricData=[
                {
                    'MetricName': 'TaskFailures',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Environment',
                            'Value': environment
                        }
                    ]
                }
            ]
        )
        raise e

def perform_health_check():
    """Perform system health checks"""
    print("Performing health checks...")
    
    # Example: Check various services
    # Add your health check logic here
    
    # Send success metric
    cloudwatch.put_metric_data(
        Namespace='ScheduledTasks',
        MetricData=[
            {
                'MetricName': 'HealthCheckSuccess',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {
                        'Name': 'Environment',
                        'Value': environment
                    }
                ]
            }
        ]
    )
    
    print("Health checks completed")

def cleanup_old_data():
    """Clean up old data from various sources"""
    print("Cleaning up old data...")
    
    # Example: Delete old logs, temporary files, etc.
    # Add your cleanup logic here
    
    print("Cleanup completed")

def send_metrics():
    """Send custom metrics to CloudWatch"""
    print("Sending metrics...")
    
    # Example custom metrics
    cloudwatch.put_metric_data(
        Namespace='ScheduledTasks',
        MetricData=[
            {
                'MetricName': 'TaskExecutions',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {
                        'Name': 'Environment',
                        'Value': environment
                    },
                    {
                        'Name': 'TaskType',
                        'Value': 'Scheduled'
                    }
                ]
            }
        ]
    )
    
    print("Metrics sent")
EOF

# Create zip file for Scheduled Task
cd lambda-functions
mv scheduled-task.py index.py
zip -r scheduled-task.zip index.py
rm index.py
cd ..

echo -e "${GREEN}✓ Scheduled Task function created${NC}"

# ================================================================
# LAMBDA LAYER (Common Libraries)
# ================================================================

echo -e "${YELLOW}Creating Lambda Layer...${NC}"

# Create a simple layer with common utilities
cat > lambda-layers/python/utils.py << 'EOF'
import json
from datetime import datetime

def format_response(status_code, body, headers=None):
    """Format API Gateway response"""
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
    }
    
    if headers:
        default_headers.update(headers)
    
    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body) if not isinstance(body, str) else body
    }

def log_event(event_type, data):
    """Log events with timestamp"""
    print(json.dumps({
        'timestamp': datetime.now().isoformat(),
        'event_type': event_type,
        'data': data
    }))

def validate_input(data, required_fields):
    """Validate input data"""
    missing_fields = [field for field in required_fields if field not in data]
    if missing_fields:
        raise ValueError(f"Missing required fields: {missing_fields}")
    return True
EOF

# Create the layer zip file
cd lambda-layers
zip -r ../common-libs.zip .
cd ..
mv common-libs.zip lambda-layers/

echo -e "${GREEN}✓ Lambda Layer created${NC}"

# ================================================================
# SUMMARY
# ================================================================

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "${BLUE}Created Lambda function packages:${NC}"
echo -e "  - lambda-functions/api-handler.zip"
echo -e "  - lambda-functions/event-processor.zip"
echo -e "  - lambda-functions/scheduled-task.zip"
echo -e "  - lambda-layers/common-libs.zip"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Run: terraform plan"
echo -e "2. Run: terraform apply"
echo -e "3. Test your APIs and Lambda functions"
