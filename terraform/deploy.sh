#!/bin/bash
# Deployment helper for AWS SA Pro Lab

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}AWS SA Pro Lab - Deployment Helper${NC}"
echo "=================================="
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from template...${NC}"
    cp terraform.tfvars.template terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars with your settings!${NC}"
    exit 1
fi

# Parse command line arguments
DOMAIN=""
ACTION="plan"

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --apply)
            ACTION="apply"
            shift
            ;;
        --destroy)
            ACTION="destroy"
            shift
            ;;
        --help)
            echo "Usage: ./deploy.sh [options]"
            echo ""
            echo "Options:"
            echo "  --domain [1-4|all]  Deploy specific domain or all"
            echo "  --apply             Apply the changes"
            echo "  --destroy           Destroy infrastructure"
            echo "  --help              Show this help"
            echo ""
            echo "Examples:"
            echo "  ./deploy.sh --domain 1          # Plan domain 1"
            echo "  ./deploy.sh --domain all --apply # Deploy all domains"
            echo "  ./deploy.sh --destroy           # Destroy everything"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Set domain flags
if [ "$DOMAIN" = "1" ]; then
    EXTRA_VARS="-var enable_domain1=true"
elif [ "$DOMAIN" = "2" ]; then
    EXTRA_VARS="-var enable_domain2=true"
elif [ "$DOMAIN" = "3" ]; then
    EXTRA_VARS="-var enable_domain3=true"
elif [ "$DOMAIN" = "4" ]; then
    EXTRA_VARS="-var enable_domain4=true"
elif [ "$DOMAIN" = "all" ]; then
    EXTRA_VARS="-var enable_domain1=true -var enable_domain2=true -var enable_domain3=true -var enable_domain4=true"
else
    EXTRA_VARS=""
fi

# Execute action
if [ "$ACTION" = "plan" ]; then
    echo -e "${YELLOW}Planning infrastructure...${NC}"
    terraform plan $EXTRA_VARS
elif [ "$ACTION" = "apply" ]; then
    echo -e "${YELLOW}Applying infrastructure...${NC}"
    terraform apply $EXTRA_VARS -auto-approve
elif [ "$ACTION" = "destroy" ]; then
    echo -e "${RED}Destroying infrastructure...${NC}"
    terraform destroy $EXTRA_VARS -auto-approve
fi

echo -e "${GREEN}✓${NC} Operation complete"
