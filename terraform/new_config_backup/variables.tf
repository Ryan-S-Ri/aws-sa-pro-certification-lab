# Root level variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "lab"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# Networking variables
variable "enable_networking" {
  description = "Enable networking module"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

# Security variables
variable "enable_security" {
  description = "Enable security module"
  type        = bool
  default     = true
}

variable "enable_web_sg" {
  description = "Enable web server security group"
  type        = bool
  default     = true
}

variable "enable_database_sg" {
  description = "Enable database security group"
  type        = bool
  default     = false
}

# Compute variables
variable "enable_compute" {
  description = "Enable compute module"
  type        = bool
  default     = false
}

# Database variables
variable "enable_database" {
  description = "Enable database module"
  type        = bool
  default     = false
}

# Storage variables
variable "enable_storage" {
  description = "Enable storage module"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable encryption for S3 buckets"
  type        = bool
  default     = true
}

# Serverless variables
variable "enable_serverless" {
  description = "Enable serverless module"
  type        = bool
  default     = false
}

# Monitoring variables
variable "enable_monitoring" {
  description = "Enable monitoring module"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}
