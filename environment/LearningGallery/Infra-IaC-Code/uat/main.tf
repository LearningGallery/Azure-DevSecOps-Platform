# Local variables for 14-character naming
locals {
  env  = var.environment
  zone = var.zone

  naming = {
    resource_group = "rgs${local.env}${local.zone}mgmgen01"
    vnet           = "vnt${local.env}${local.zone}mgmnet01"
    nat_gateway    = "nat${local.env}${local.zone}mgmnet01"
    nat_pip        = "pip${local.env}${local.zone}mgmnat01"
    key_vault      = "kvt${local.env}${local.zone}mgmsec01"
  }

  common_tags = merge(
    var.tags,
    {
      Environment = var.environment == "u" ? "UAT" : "Production"
      Location    = var.location
      Project     = var.project_id
    }
  )
}

data "azurerm_client_config" "current" {}

# Module: Foundation
module "foundation" {
  source = "../../../../modules/foundation"

  resource_group_name = local.naming.resource_group
  location            = var.location
  tags                = local.common_tags
}

# Module: Network
module "network" {
  source = "../../../../modules/network"

  vnet_name            = local.naming.vnet
  nat_gateway_name     = local.naming.nat_gateway
  nat_gateway_pip_name = local.naming.nat_pip
  vnet_cidr            = "10.10.0.0/16"
  subnets_csv_path     = "${path.module}/data/subnets.csv"
  resource_group_name  = module.foundation.resource_group_name
  location             = var.location
  tags                 = local.common_tags
  enable_bastion       = var.enable_bastion
  bastion_name         = "bas${local.env}${local.zone}mgmnet01"
  depends_on           = [module.foundation]
}

# Module: Security
module "security" {
  source = "../../../../modules/security"

  key_vault_name             = local.naming.key_vault
  nsg_rules_csv_path         = "${path.module}/data/nsg_rules.csv"
  subnet_ids                 = module.network.subnet_ids
  index                      = "01"
  private_endpoint_subnet_id = module.network.subnet_ids["snet-monitor"]
  key_vault_dns_zone_id      = module.network.private_dns_zone_ids["privatelink.vaultcore.azure.net"]
  tenant_id                  = var.azure_tenant_id
  current_user_object_id     = data.azurerm_client_config.current.object_id
  resource_group_name        = module.foundation.resource_group_name
  location                   = var.location
  tags                       = local.common_tags

  depends_on = [module.network]
}

# Module: Storage
module "storage" {
  source = "../../../../modules/storage"

  storage_account_name    = "stg${local.env}${local.zone}mgmlog01"
  account_tier            = "Standard"
  replication_type        = "LRS"
  enable_private_endpoint = true
  subnet_id               = module.network.subnet_ids["snet-monitor"]
  vnet_id                 = module.network.vnet_id
  private_dns_zone_id     = module.network.private_dns_zone_ids["privatelink.blob.core.windows.net"]

  containers = {
    logs = {
      name        = "logs"
      access_type = "private"
    }
  }

  enable_lifecycle_management = true
  lifecycle_rules = {
    archive_old_logs = {
      enabled = true
      filters = {
        prefix_match = ["logs/"]
        blob_types   = ["blockBlob"]
      }
      actions = {
        base_blob = {
          tier_to_cool_after_days    = 30
          tier_to_archive_after_days = 90
          delete_after_days          = 730
        }
      }
    }
  }

  resource_group_name = module.foundation.resource_group_name
  location            = var.location
  tags                = local.common_tags

  depends_on = [module.network]
}

# Module: Monitor
module "monitor" {
  source = "../../../../modules/monitor"

  workspace_name = "law${local.env}${local.zone}mgmmon01"
  ampls_name     = "pls${local.env}${local.zone}mgmmon01"

  retention_days             = 90
  daily_quota_gb             = 10
  internet_ingestion_enabled = false
  internet_query_enabled     = false

  ampls_subnet_id = module.network.subnet_ids["snet-monitor"]
  vnet_id         = module.network.vnet_id

  monitor_dns_zone_ids = module.network.private_dns_zone_ids

  archive_storage_account_id = module.storage.storage_account_id

  environment         = var.environment
  resource_group_name = module.foundation.resource_group_name
  location            = var.location
  tags                = local.common_tags

  depends_on = [module.storage]
}

# Module: Compute
module "compute" {
  source = "../../../../modules/compute"

  infrastructure_csv_path       = "${path.module}/data/infrastructure.csv"
  linux_bootstrap_script_path   = "${path.module}/scripts/linux_bootstrap.sh"
  windows_bootstrap_script_path = "${path.module}/scripts/windows_bootstrap.ps1"

  compute_subnet_id      = module.network.subnet_ids["snet-vms"]
  ssh_public_key_path    = var.ssh_public_key_path
  windows_admin_password = var.windows_admin_password

  resource_group_name = module.foundation.resource_group_name
  location            = var.location
  tags                = local.common_tags

  depends_on = [module.network, module.security]
}

# Module: AKS
module "aks" {
  source = "../../../../modules/container"

  cluster_name = "aks${local.env}${local.zone}mgmk8s01"
  dns_prefix   = "aks${local.env}${local.zone}"

  vnet_subnet_id             = module.network.subnet_ids["snet-aks"]
  log_analytics_workspace_id = module.monitor.workspace_id
  data_collection_rule_id    = module.monitor.dcr_container_insights_id

  default_node_pool = {
    name                = "system"
    vm_size             = "Standard_B2s"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
    os_disk_size_gb     = 128
    type                = "VirtualMachineScaleSets"
  }

  resource_group_name = module.foundation.resource_group_name
  location            = var.location
  tags                = local.common_tags

  depends_on = [module.monitor]
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "acr${local.env}${local.zone}mgmreg01"
  resource_group_name = module.foundation.resource_group_name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false

  network_rule_set {
    default_action = "Deny"
  }

  public_network_access_enabled = false

  tags = local.common_tags
}

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr" {
  name                = "acr${local.env}${local.zone}mgmreg01pe"
  location            = var.location
  resource_group_name = module.foundation.resource_group_name
  subnet_id           = module.network.subnet_ids["snet-monitor"]

  private_service_connection {
    name                           = "acr-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  tags = local.common_tags
}

# Role Assignment: AKS to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}
