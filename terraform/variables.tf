variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "sa-pro-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery region"
  type        = string
  default     = "us-west-2"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Terraform = "true"
    Purpose   = "aws-certification-lab"
  }
}

# Domain toggles
variable "enable_shared_infrastructure" {
  description = "Enable shared infrastructure deployment"
  type        = bool
  default     = true
}

variable "enable_domain1" {
  description = "Enable Domain 1: Organizational Complexity"
  type        = bool
  default     = false
}

variable "enable_domain2" {
  description = "Enable Domain 2: New Solutions"
  type        = bool
  default     = false
}

variable "enable_domain3" {
  description = "Enable Domain 3: Continuous Improvement"
  type        = bool
  default     = false
}

variable "enable_domain4" {
  description = "Enable Domain 4: Migration and Modernization"
  type        = bool
  default     = false
}

# Notification settings
# Study config compatibility variables







# Add other variables referenced in study configs










variable "notification_email" {
  description = "Email for notifications"
  type        = string
  default     = ""
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_domain5" {
  description = "Enable Domain 5: Enterprise Architecture"
  type        = bool
  default     = false
}

variable "enable_domain6" {
  description = "Enable Domain 6: Advanced Migration and Modernization"
  type        = bool
  default     = false
}
