#!/bin/bash
# networking-status.sh - Check advanced networking service status

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_networking_overview() {
    print_status "Getting advanced networking infrastructure overview..."
    
    echo ""
    print_success "Networking Services Status:"
    
    # Check Transit Gateway
    local tgw_id=$(terraform output -json transit_gateway_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$tgw_id" != "Not deployed" && "$tgw_id" != "" && "$tgw_id" != "null" ]]; then
        echo "✅ Transit Gateway: $tgw_id"
    else
        echo "❌ Transit Gateway: Not deployed"
    fi
    
    # Check VPC Peering
    local peering_id=$(terraform output -json vpc_peering_connection_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$peering_id" != "Not deployed" && "$peering_id" != "" && "$peering_id" != "null" ]]; then
        echo "✅ VPC Peering: $peering_id"
    else
        echo "❌ VPC Peering: Not deployed"
    fi
    
    # Check CloudFront
    local cf_id=$(terraform output -json cloudfront_distribution_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$cf_id" != "Not deployed" && "$cf_id" != "" && "$cf_id" != "null" ]]; then
        echo "✅ CloudFront: $cf_id"
        local cf_domain=$(terraform output -json cloudfront_domain_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        if [[ "$cf_domain" != "Not deployed" && "$cf_domain" != "" ]]; then
            echo "   Domain: https://$cf_domain"
        fi
    else
        echo "❌ CloudFront: Not deployed"
    fi
    
    # Check Route 53
    local r53_zone=$(terraform output -json route53_private_zone_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$r53_zone" != "Not deployed" && "$r53_zone" != "" && "$r53_zone" != "null" ]]; then
        echo "✅ Route 53 Private Zone: $r53_zone"
    else
        echo "❌ Route 53 Private Zone: Not deployed"
    fi
    
    # Check VPN
    local vpn_id=$(terraform output -json vpn_connection_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$vpn_id" != "Not deployed" && "$vpn_id" != "" && "$vpn_id" != "null" ]]; then
        echo "✅ VPN Connection: $vpn_id"
    else
        echo "❌ VPN Connection: Not deployed"
    fi
}

show_transit_gateway_details() {
    print_status "Transit Gateway detailed information..."
    
    if command -v aws &> /dev/null; then
        local tgw_id=$(terraform output -json transit_gateway_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        
        if [[ "$tgw_id" != "Not deployed" && "$tgw_id" != "" && "$tgw_id" != "null" ]]; then
            echo ""
            print_success "Transit Gateway Details:"
            aws ec2 describe-transit-gateways --transit-gateway-ids "$tgw_id" --query 'TransitGateways[0].{ID:TransitGatewayId,State:State,ASN:AmazonSideAsn,Owner:OwnerId}' --output table 2>/dev/null || echo "Unable to get TGW details"
            
            echo ""
            print_success "Transit Gateway Attachments:"
            aws ec2 describe-transit-gateway-attachments --filters "Name=transit-gateway-id,Values=$tgw_id" --query 'TransitGatewayAttachments[].{ID:TransitGatewayAttachmentId,Type:ResourceType,State:State,VPC:ResourceId}' --output table 2>/dev/null || echo "Unable to get TGW attachments"
        else
            echo "❌ Transit Gateway not deployed"
        fi
    else
        echo "AWS CLI not available for detailed TGW information"
    fi
}

show_vpc_peering_details() {
    print_status "VPC Peering detailed information..."
    
    if command -v aws &> /dev/null; then
        local peering_id=$(terraform output -json vpc_peering_connection_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        
        if [[ "$peering_id" != "Not deployed" && "$peering_id" != "" && "$peering_id" != "null" ]]; then
            echo ""
            print_success "VPC Peering Details:"
            aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$peering_id" --query 'VpcPeeringConnections[0].{ID:VpcPeeringConnectionId,Status:Status.Code,RequesterVPC:RequesterVpcInfo.VpcId,AccepterVPC:AccepterVpcInfo.VpcId}' --output table 2>/dev/null || echo "Unable to get peering details"
        else
            echo "❌ VPC Peering not deployed"
        fi
    else
        echo "AWS CLI not available for detailed peering information"
    fi
}

show_cloudfront_details() {
    print_status "CloudFront distribution details..."
    
    if command -v aws &> /dev/null; then
        local cf_id=$(terraform output -json cloudfront_distribution_id 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
        
        if [[ "$cf_id" != "Not deployed" && "$cf_id" != "" && "$cf_id" != "null" ]]; then
            echo ""
            print_success "CloudFront Distribution:"
            aws cloudfront get-distribution --id "$cf_id" --query 'Distribution.{ID:Id,Status:Status,DomainName:DomainName,PriceClass:DistributionConfig.PriceClass}' --output table 2>/dev/null || echo "Unable to get CloudFront details"
            
            local cf_domain=$(terraform output -json cloudfront_domain_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
            if [[ "$cf_domain" != "Not deployed" && "$cf_domain" != "" ]]; then
                echo ""
                print_warning "Test your CloudFront distribution:"
                echo "  curl -I https://$cf_domain"
                echo "  Or visit: https://$cf_domain"
            fi
        else
            echo "❌ CloudFront not deployed"
        fi
    else
        echo "AWS CLI not available for CloudFront details"
    fi
}

test_connectivity() {
    print_status "Testing network connectivity..."
    
    echo ""
    print_success "Basic Connectivity Tests:"
    
    # Test CloudFront
    local cf_domain=$(terraform output -json cloudfront_domain_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$cf_domain" != "Not deployed" && "$cf_domain" != "" && "$cf_domain" != "null" ]]; then
        print_status "Testing CloudFront distribution..."
        if curl -s -o /dev/null -w "%{http_code}" "https://$cf_domain" | grep -q "200\|403"; then
            echo "✅ CloudFront: Responding"
        else
            echo "❌ CloudFront: Not responding or not ready"
        fi
    fi
    
    # Test ALB (if compute tier enabled)
    local alb_dns=$(terraform output -json web_alb_dns_name 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    if [[ "$alb_dns" != "Not deployed" && "$alb_dns" != "" && "$alb_dns" != "null" ]]; then
        print_status "Testing Application Load Balancer..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$alb_dns" | grep -q "200"; then
            echo "✅ ALB: Responding"
        else
            echo "❌ ALB: Not responding or unhealthy targets"
        fi
    fi
}

case ${1:-""} in
    "overview"|"status"|"")
        show_networking_overview
        ;;
    "tgw"|"transit-gateway")
        show_transit_gateway_details
        ;;
    "peering"|"vpc-peering")
        show_vpc_peering_details
        ;;
    "cloudfront"|"cdn")
        show_cloudfront_details
        ;;
    "test"|"connectivity")
        test_connectivity
        ;;
    "all")
        show_networking_overview
        echo ""
        show_transit_gateway_details
        echo ""
        show_vpc_peering_details
        echo ""
        show_cloudfront_details
        echo ""
        test_connectivity
        ;;
    "help"|"-h")
        echo "Usage: ./scripts/networking-status.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  overview, status   Show networking services overview"
        echo "  tgw, transit-gateway  Show Transit Gateway details"
        echo "  peering, vpc-peering  Show VPC Peering details"
        echo "  cloudfront, cdn    Show CloudFront distribution details"
        echo "  test, connectivity Test network connectivity"
        echo "  all                Show all networking information"
        echo "  help               Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './scripts/networking-status.sh help' for usage"
        exit 1
        ;;
esac
