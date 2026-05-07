output "resource_group_name" {
  description = "Resource Group Name"
  value       = module.foundation.resource_group_name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.network.vnet_id
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.security.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.monitor.workspace_id
}

output "aks_cluster_name" {
  description = "AKS Cluster Name"
  value       = module.aks.cluster_name
}

output "aks_kube_config" {
  description = "AKS Kubeconfig"
  value       = module.aks.kube_config
  sensitive   = true
}

output "acr_login_server" {
  description = "Container Registry Login Server"
  value       = azurerm_container_registry.main.login_server
}

output "linux_vm_private_ips" {
  description = "Linux VM Private IPs"
  value       = module.compute.linux_vm_private_ips
}

output "windows_vm_private_ips" {
  description = "Windows VM Private IPs"
  value       = module.compute.windows_vm_private_ips
}
