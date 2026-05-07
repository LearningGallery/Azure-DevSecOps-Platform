variable "cluster_name" { type = string }
variable "dns_prefix" { type = string }
variable "vnet_subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "data_collection_rule_id" { type = string }

variable "default_node_pool" {
  type = object({
    name                = string
    vm_size             = string
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
    os_disk_size_gb     = number
    type                = string
  })
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
