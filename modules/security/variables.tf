variable "nsg_rules_csv_path" {
  description = "Path to nsg_rules.csv"
  type        = string
}

variable "key_vault_name" {
  description = "14-char Key Vault name (kvtXXXXXXXXXXX)"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to IDs"
  type        = map(string)
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "key_vault_dns_zone_id" {
  type = string
}

variable "runner_ip" {
  description = "The dynamic IP of the GitHub Actions runner"
  type        = string
  default     = "" # Default to empty so it doesn't break local runs
}

variable "tenant_id" { type = string }
variable "current_user_object_id" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "index" { type = string }
variable "tags" { type = map(string) }
