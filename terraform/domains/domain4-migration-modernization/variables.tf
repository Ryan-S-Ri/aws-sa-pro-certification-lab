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
