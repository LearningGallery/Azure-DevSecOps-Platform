variable "environment" {
  description = "Environment (u=UAT, p=PROD)"
  type        = string
  default     = "u"
  validation {
    condition     = contains(["u", "p"], var.environment)
    error_message = "Environment must be 'u' (UAT) or 'p' (PROD)"
  }
}

variable "zone" {
  description = "Azure zone (ia=Singapore, ie=Hong Kong)"
  type        = string
  default     = "ia"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southeastasia"
}

variable "project_id" {
  description = "Project ID (3 chars)"
  type        = string
  default     = "prj"
}

variable "windows_admin_password" {
  description = "Windows admin password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    ManagedBy  = "Terraform"
    CostCenter = "IT-Infrastructure"
    Compliance = "ISO27001"
  }
}

variable "enable_bastion" {
  description = "Toggle to deploy Azure Bastion Developer tier in this environment"
  type        = bool
  default     = false
}
