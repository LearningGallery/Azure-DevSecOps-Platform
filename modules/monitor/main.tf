resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  sku                        = "PerGB2018"
  retention_in_days          = var.retention_days
  daily_quota_gb             = var.daily_quota_gb
  internet_ingestion_enabled = var.internet_ingestion_enabled
  internet_query_enabled     = var.internet_query_enabled
  
  tags = var.tags
}

resource "azurerm_log_analytics_solution" "solutions" {
  for_each = toset([
    "Security",
    "Updates",
    "VMInsights",
    "ContainerInsights",
    "ServiceMap"
  ])
  
  solution_name         = each.value
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }
  
  tags = var.tags
}

resource "azurerm_monitor_data_collection_endpoint" "main" {
  name                          = "${var.workspace_name}-dce"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "Linux"
  public_network_access_enabled = false
  
  tags = var.tags
}

resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "dcr-containerinsights-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents"]
      
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Include"
          namespaces             = ["default", "kube-system", "production"]
          enableContainerLogV2   = true
        }
      })
    }
  }
  
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "destination-law"
    }
  }
  
  data_flow {
    streams      = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents"]
    destinations = ["destination-law"]
  }
  
  tags = var.tags
}

resource "azurerm_monitor_private_link_scope" "main" {
  name                  = var.ampls_name
  resource_group_name   = var.resource_group_name
  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"
  
  tags = var.tags
}

resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "ampls-law"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_private_endpoint" "ampls" {
  name                = "${var.ampls_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.ampls_subnet_id
  
  private_service_connection {
    name                           = "${var.ampls_name}-psc"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main.id
    is_manual_connection           = false
    subresource_names              = ["azuremonitor"]
  }
  
  private_dns_zone_group {
    name = "ampls-dns-group"
    private_dns_zone_ids = [
      var.monitor_dns_zone_ids["privatelink.monitor.azure.com"],
      var.monitor_dns_zone_ids["privatelink.oms.opinsights.azure.com"],
      var.monitor_dns_zone_ids["privatelink.ods.opinsights.azure.com"]
    ]
  }
  
  tags = var.tags
}

resource "azurerm_log_analytics_linked_storage_account" "archive" {
  data_source_type      = "CustomLogs"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  storage_account_ids   = [var.archive_storage_account_id]
}
