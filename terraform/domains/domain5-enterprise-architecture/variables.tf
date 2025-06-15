# Domain 5: Enterprise Architecture Variables

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
  default     = {}
}

# Organizations variables
variable "enable_organizations" {
  description = "Enable AWS Organizations configuration"
  type        = bool
  default     = false
}

variable "enable_security_control_policies" {
  description = "Enable Service Control Policies"
  type        = bool
  default     = false
}

# Cross-account access variables
variable "enable_cross_account_roles" {
  description = "Enable cross-account IAM roles"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of trusted AWS account IDs for cross-account access"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = "enterprise-lab-external-id"
}

# Enterprise SSO variables
variable "enable_enterprise_sso" {
  description = "Enable enterprise SSO configuration"
  type        = bool
  default     = false
}

variable "saml_metadata_document" {
  description = "SAML metadata document for SSO configuration"
  type        = string
  default     = <<-EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" entityID="https://example.com/saml/metadata">
      <md:IDPSSODescriptor WantAuthnRequestsSigned="false" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <md:SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://example.com/saml/sso"/>
      </md:IDPSSODescriptor>
    </md:EntityDescriptor>
  EOF
}

# Governance variables
variable "enable_config_aggregator" {
  description = "Enable AWS Config aggregator for enterprise governance"
  type        = bool
  default     = false
}

variable "enable_security_hub_enterprise" {
  description = "Enable Security Hub for enterprise security management"
  type        = bool
  default     = false
}

variable "enable_guardduty_enterprise" {
  description = "Enable GuardDuty for enterprise threat detection"
  type        = bool
  default     = false
}

variable "guardduty_finding_frequency" {
  description = "GuardDuty finding publishing frequency"
  type        = string
  default     = "SIX_HOURS"
  
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_frequency)
    error_message = "GuardDuty finding frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

# Enterprise networking variables
variable "enable_enterprise_transit_gateway" {
  description = "Enable enterprise Transit Gateway"
  type        = bool
  default     = false
}

variable "enable_ram_sharing" {
  description = "Enable Resource Access Manager sharing"
  type        = bool
  default     = false
}

# Cost management variables
variable "enable_enterprise_budgets" {
  description = "Enable enterprise budget monitoring"
  type        = bool
  default     = false
}

variable "enterprise_budget_limit" {
  description = "Enterprise budget limit in USD"
  type        = string
  default     = "1000"
}

variable "monitored_account_ids" {
  description = "List of account IDs to monitor in budget"
  type        = list(string)
  default     = []
}

variable "notification_email" {
  description = "Email for budget notifications"
  type        = string
  default     = ""
}

# Compliance variables
variable "enable_tagging_compliance" {
  description = "Enable tagging compliance monitoring"
  type        = bool
  default     = false
}
