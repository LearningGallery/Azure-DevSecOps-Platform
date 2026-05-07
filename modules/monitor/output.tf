output "workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "workspace_customer_id" {
  value     = azurerm_log_analytics_workspace.main.workspace_id
  sensitive = true
}

output "primary_shared_key" {
  value     = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive = true
}

output "dcr_container_insights_id" {
  value = azurerm_monitor_data_collection_rule.container_insights.id
}

output "ampls_id" {
  value = azurerm_monitor_private_link_scope.main.id
}
