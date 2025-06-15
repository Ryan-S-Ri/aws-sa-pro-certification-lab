# Minimal VPC for SA Pro lab
resource "aws_vpc" "primary" {
  provider             = aws.primary
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-vpc"
    Type = "primary"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-igw"
  })
}

# Public subnet (just one for minimal setup)
resource "aws_subnet" "public" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.primary_region}a"
  map_public_ip_on_launch = true
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-public-subnet"
    Type = "public"
  })
}

# Private subnet (required by some resources)
resource "aws_subnet" "private" {
  provider          = aws.primary
  count             = 2
  vpc_id            = aws_vpc.primary.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-private-${count.index + 1}"
    Type = "private"
  })
}

data "aws_availability_zones" "available" {
  provider = aws.primary
  state    = "available"
}

# Route table for public subnet
resource "aws_route_table" "public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.common_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  provider       = aws.primary
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
