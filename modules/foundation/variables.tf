variable "resource_group_name" {
  description = "14-char CAF resource group name (rgsXXXXXXXXXXX)"
  type        = string
  validation {
    condition     = can(regex("^rgs[pu][a-z]{2}[a-z]{3}[a-z0-9]{3}[0-9]{2}$", var.resource_group_name))
    error_message = "Must follow: rgs[env][zone][tier][role][index]"
  }
}

variable "location" {
  type = string
}

variable "enable_azapi" {
  type    = bool
  default = false
}

variable "tags" {
  type = map(string)
}
