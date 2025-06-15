variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID from shared infrastructure"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs from shared infrastructure"
  type        = list(string)
  default     = []
}

variable "enable_organizations" {
  description = "Enable AWS Organizations setup"
  type        = bool
  default     = false
}

variable "enable_transit_gateway" {
  description = "Enable Transit Gateway setup"
  type        = bool
  default     = true
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = "SA-PRO-LAB-2024"
}
