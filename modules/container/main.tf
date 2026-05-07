resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  
  default_node_pool {
    name                = var.default_node_pool.name
    vm_size             = var.default_node_pool.vm_size
    vnet_subnet_id      = var.vnet_subnet_id
    enable_auto_scaling = var.default_node_pool.enable_auto_scaling
    min_count           = var.default_node_pool.min_count
    max_count           = var.default_node_pool.max_count
    os_disk_size_gb     = var.default_node_pool.os_disk_size_gb
    type                = var.default_node_pool.type
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
  
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
  
  azure_policy_enabled              = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  
  tags = var.tags
}

resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = "aks-dcr-association"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = var.data_collection_rule_id
}
