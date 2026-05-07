variable "vnet_name" {
  description = "14-char VNet name (vntXXXXXXXXXXX)"
  type        = string
}

variable "nat_gateway_name" {
  description = "14-char NAT Gateway name"
  type        = string
}

variable "nat_gateway_pip_name" {
  description = "14-char Public IP name"
  type        = string
}

variable "vnet_cidr" {
  type = string
}

variable "subnets_csv_path" {
  description = "Path to subnets.csv"
  type        = string
}

variable "private_dns_zones" {
  description = "List of Private DNS zones"
  type        = list(string)
  default = [
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.vaultcore.azure.net"
  ]
}

variable "enable_bastion" {
  description = "Feature toggle to deploy Azure Bastion (Developer Tier)"
  type        = bool
  default     = false
}

variable "bastion_name" {
  description = "Name of the Bastion Host"
  type        = string
  default     = ""
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

