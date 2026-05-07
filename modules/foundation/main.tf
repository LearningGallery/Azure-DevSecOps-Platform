# Resource Group with CAF naming
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Azure API Resources (Future extensibility)
resource "azapi_resource" "placeholder" {
  count     = var.enable_azapi ? 1 : 0
  type      = "Microsoft.Resources/deployments@2021-04-01"
  name      = "${var.resource_group_name}-azapi"
  parent_id = azurerm_resource_group.main.id
  
  body = {
    properties = {
      mode = "Incremental"
      template = {
        "$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
        contentVersion = "1.0.0.0"
        resources = []
      }
    }
  }
}
