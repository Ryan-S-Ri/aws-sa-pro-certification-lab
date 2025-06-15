# Exercise 3: Global Content Delivery

## Objective
Implement CloudFront distribution for global content delivery with caching strategies.

## Prerequisites
- S3 bucket with static content
- CloudFront distribution created
- Sample content uploaded

## Duration
30 minutes

## Tasks

### Task 1: Upload Content to S3
```bash
# Create sample content
echo "<html><body><h1>Hello from CloudFront!</h1></body></html>" > index.html

# Upload to S3
aws s3 cp index.html s3://$(terraform output -raw s3_bucket_name)/

# Set bucket policy for CloudFront
aws s3api put-bucket-policy --bucket $(terraform output -raw s3_bucket_name) \
  --policy file://bucket-policy.json
```

### Task 2: Configure CloudFront Behaviors
1. Set cache behaviors
2. Configure TTL values
3. Enable compression

### Task 3: Test Global Distribution
```bash
# Get CloudFront domain
CF_DOMAIN=$(terraform output -raw cloudfront_domain)

# Test from different locations
curl -I https://$CF_DOMAIN/index.html

# Check cache headers
curl -I https://$CF_DOMAIN/index.html | grep -i cache
```

## Validation
- Content serves from CloudFront
- Cache headers are correct
- Global edge locations serve content
