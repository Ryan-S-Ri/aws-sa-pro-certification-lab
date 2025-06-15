#!/bin/bash
# study-deploy.sh - Progressive AWS Certification Lab Deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

estimate_cost() {
    case $1 in
        "domain1-security") echo "~\$1-3/day (Security services, basic networking)" ;;
        "domain2-resilient") echo "~\$3-6/day (+ Compute tier with t3.micro instances)" ;;
        "domain3-performance") echo "~\$5-10/day (+ Database tier, caching)" ;;
        "domain4-cost-optimized") echo "~\$6-12/day (+ Monitoring, cost tools)" ;;
        "full-lab") echo "~\$15-25/day (Full production-like setup)" ;;
    esac
}

show_domain_features() {
    echo ""
    print_status "Domain Features:"
    case $1 in
        "domain1-security")
            echo "  🔐 Core Security:"
            echo "    - VPC with security groups and NACLs"
            echo "    - IAM roles and policies"
            echo "    - KMS encryption"
            echo "    - CloudTrail logging"
            echo "    - GuardDuty threat detection"
            echo "    - AWS Config compliance"
            echo "    - VPC Flow Logs"
            ;;
        "domain2-resilient")
            echo "  🔐 Security (from Domain 1) +"
            echo "  🏗️  Resilient Architecture:"
            echo "    - Auto Scaling Groups"
            echo "    - Application Load Balancer"
            echo "    - Multi-AZ deployment options"
            echo "    - Health checks and monitoring"
            echo "    - Bastion host for secure access"
            echo "    - EFS for shared storage"
            ;;
        "domain3-performance")
            echo "  🔐 Security + 🏗️ Resilience +"
            echo "  ⚡ High Performance:"
            echo "    - RDS Aurora databases"
            echo "    - ElastiCache for caching"
            echo "    - CloudFront CDN"
            echo "    - Database read replicas"
            echo "    - Performance Insights"
            echo "    - S3 performance optimizations"
            ;;
        "domain4-cost-optimized")
            echo "  🔐 Security + 🏗️ Resilience + ⚡ Performance +"
            echo "  💰 Cost Optimization:"
            echo "    - CloudWatch detailed monitoring"
            echo "    - AWS Budgets and alerts"
            echo "    - Cost allocation tags"
            echo "    - S3 Intelligent Tiering"
            echo "    - Spot instance configurations"
            echo "    - Lifecycle policies"
            ;;
        "full-lab")
            echo "  🎯 Everything from Domains 1-4 +"
            echo "  🌐 Advanced Features:"
            echo "    - Transit Gateway"
            echo "    - VPC Peering"
            echo "    - Cross-region replication"
            echo "    - Disaster recovery testing"
            echo "    - VPN connections"
            echo "    - Multi-region setup"
            ;;
    esac
}

deploy_domain() {
    local domain=$1
    local config_file="study-configs/${domain}.tfvars"
    
    if [[ ! -f $config_file ]]; then
        print_error "Configuration file $config_file not found!"
        exit 1
    fi
    
    print_status "Deploying $domain configuration..."
    show_domain_features $domain
    
    local cost=$(estimate_cost $domain)
    echo ""
    print_warning "Estimated daily cost: $cost"
    echo ""
    
    read -p "Continue with deployment? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    print_status "Running terraform plan..."
    terraform plan -var-file="$config_file" -out="${domain}.tfplan"
    
    echo ""
    read -p "Apply this plan? (y/N): " apply_confirm
    if [[ $apply_confirm == [yY] ]]; then
        print_status "Applying terraform configuration..."
        terraform apply "${domain}.tfplan"
        print_success "✅ $domain deployed successfully!"
        
        print_status "Getting connection information..."
        echo ""
        terraform output
        
        echo "$(date): Deployed $domain" >> .deployment_history
    else
        print_status "Apply cancelled. Cleaning up plan file..."
        rm -f "${domain}.tfplan"
    fi
}

destroy_deployment() {
    print_warning "⚠️  This will destroy ALL current AWS resources!"
    echo ""
    read -p "Are you sure you want to destroy everything? (type 'destroy' to confirm): " confirm
    
    if [[ $confirm == "destroy" ]]; then
        print_status "Destroying infrastructure..."
        terraform destroy -auto-approve
        print_success "✅ Infrastructure destroyed successfully!"
        echo "$(date): Destroyed deployment" >> .deployment_history
    else
        print_status "Destroy cancelled."
    fi
}

show_status() {
    print_status "Current Terraform State:"
    terraform show
    
    if [[ -f .deployment_history ]]; then
        echo ""
        print_status "Recent deployments:"
        tail -5 .deployment_history
    fi
}

# Main script
main() {
    echo "🏗️  AWS Certification Lab - Progressive Study Deployment"
    echo "======================================================"
    
    case ${1:-""} in
        "domain1"|"d1") deploy_domain "domain1-security" ;;
        "domain2"|"d2") deploy_domain "domain2-resilient" ;;
        "domain3"|"d3") deploy_domain "domain3-performance" ;;
        "domain4"|"d4") deploy_domain "domain4-cost-optimized" ;;
        "full"|"full-lab") deploy_domain "full-lab" ;;
        "database"|"db") deploy_domain "database-only" ;;
        "monitoring"|"mon") deploy_domain "monitoring-only" ;;
        "destroy"|"down") destroy_deployment ;;
        "status"|"show") show_status ;;
        "help"|"-h"|"--help"|"")
            echo ""
            echo "Usage: ./study-deploy.sh [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  domain1, d1     Deploy Domain 1: Security (builds foundation)"
            echo "  domain2, d2     Deploy Domain 2: Resilience (builds on Domain 1)"
            echo "  domain3, d3     Deploy Domain 3: Performance (builds on 1+2)"
            echo "  domain4, d4     Deploy Domain 4: Cost Optimization (builds on 1+2+3)"
            echo "  full, full-lab  Deploy complete lab (all domains + advanced features)"
  database        Deploy database-only configuration (focused study)
  monitoring      Deploy monitoring-only configuration (focused study)
            echo "  destroy, down   Destroy all infrastructure"
            echo "  status, show    Show current deployment status"
            echo "  help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./study-deploy.sh domain1    # Start with security basics"
            echo "  ./study-deploy.sh d2         # Add resilience features"
            echo "  ./study-deploy.sh destroy    # Clean up after study session"
            echo ""
            print_status "Progressive study approach:"
            echo "  1. Start with Domain 1 (Security foundation)"
            echo "  2. Add Domain 2 (Resilience) when ready"
            echo "  3. Add Domain 3 (Performance) for database/caching study"
            echo "  4. Add Domain 4 (Cost) for monitoring and optimization"
            echo "  5. Use 'full-lab' for final comprehensive practice"
            echo ""
            echo "💡 Always run 'destroy' after your study session to save costs!"
            ;;
        *) print_error "Unknown command: $1"
           echo "Run './study-deploy.sh help' for usage information."
           exit 1 ;;
    esac
}

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed or not in PATH"
    exit 1
fi

if [[ ! -f "main.tf" ]]; then
    print_error "No main.tf found. Please run this script from your Terraform directory."
    exit 1
fi

main "$@"
