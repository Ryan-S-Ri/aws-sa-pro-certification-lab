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
