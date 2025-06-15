#!/bin/bash
# database-connect.sh - Helper script for connecting to databases

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

show_connection_info() {
    print_status "Getting database connection information..."
    
    echo ""
    print_success "Database Endpoints:"
    terraform output -json database_endpoints 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
    
    echo ""
    print_success "DynamoDB Tables:"
    terraform output -json dynamodb_tables 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' || echo "Run terraform apply first"
    
    echo ""
    print_warning "Connection Examples:"
    echo "MySQL (from bastion):"
    echo "  mysql -h \$(terraform output -raw database_endpoints | jq -r '.aurora_mysql_writer') -u admin -p labdb"
    echo ""
    echo "Redis (from app instances):"
    echo "  redis-cli -h \$(terraform output -raw database_endpoints | jq -r '.redis_primary') -a 'LabRedisAuth123456789!'"
    echo ""
    echo "DynamoDB (AWS CLI):"
    echo "  aws dynamodb scan --table-name \$(terraform output -raw dynamodb_tables | jq -r '.sessions')"
}

show_secrets() {
    print_status "Database secrets in AWS Secrets Manager:"
    echo ""
    
    if aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `aws-cert-lab`)].Name' --output table 2>/dev/null; then
        echo ""
        print_warning "To retrieve a secret:"
        echo "aws secretsmanager get-secret-value --secret-id aws-cert-lab/database/mysql/master --query SecretString --output text | jq"
    else
        echo "No secrets found or AWS CLI not configured"
    fi
}

case ${1:-""} in
    "info"|"show"|"")
        show_connection_info
        ;;
    "secrets")
        show_secrets
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/database-connect.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  info, show    Show database connection information"
        echo "  secrets       Show secrets in AWS Secrets Manager"
        echo "  help          Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/database-connect.sh help' for usage"
        exit 1
        ;;
esac
