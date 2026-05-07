variable "workspace_name" { type = string }
variable "ampls_name" { type = string }
variable "retention_days" { type = number }
variable "daily_quota_gb" { type = number }
variable "internet_ingestion_enabled" { type = bool }
variable "internet_query_enabled" { type = bool }
variable "ampls_subnet_id" { type = string }
variable "vnet_id" { type = string }
variable "archive_storage_account_id" { type = string }
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "monitor_dns_zone_ids" {
  type = map(string)
}
