variable "storage_account_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only"
  }
}

variable "account_tier" {
  type    = string
  default = "Standard"
}

variable "replication_type" {
  type    = string
  default = "LRS"
}

variable "containers" {
  type = map(object({
    name        = string
    access_type = string
  }))
  default = {}
}

variable "enable_private_endpoint" {
  type    = bool
  default = false
}

variable "subnet_id" {
  type    = string
  default = null
}

variable "vnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type    = string
  default = null
}

variable "enable_lifecycle_management" {
  type    = bool
  default = false
}

variable "lifecycle_rules" {
  type = map(object({
    enabled = bool
    filters = object({
      prefix_match = list(string)
      blob_types   = list(string)
    })
    actions = object({
      base_blob = map(number)
    })
  }))
  default = {}
}

variable "runner_ip" {
  description = "The dynamic IP of the GitHub Actions runner"
  type        = string
  default     = "" # Default to empty so it doesn't break local runs
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
