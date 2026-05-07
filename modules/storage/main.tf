data "http" "myip" { url = "https://ipv4.icanhazip.com" }

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = [chomp(data.http.myip.response_body), var.runner_ip != "" ? var.runner_ip : ""]
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "containers" {
  for_each              = var.containers
  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = each.value.access_type
}

resource "azurerm_private_endpoint" "storage" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.storage_account_name}pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_storage_management_policy" "lifecycle" {
  count              = var.enable_lifecycle_management ? 1 : 0
  storage_account_id = azurerm_storage_account.main.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      name    = rule.key
      enabled = rule.value.enabled
      filters {
        prefix_match = rule.value.filters.prefix_match
        blob_types   = rule.value.filters.blob_types
      }
      actions {
        base_blob {
          tier_to_cool_after_days_since_modification_greater_than    = lookup(rule.value.actions.base_blob, "tier_to_cool_after_days", null)
          tier_to_archive_after_days_since_modification_greater_than = lookup(rule.value.actions.base_blob, "tier_to_archive_after_days", null)
          delete_after_days_since_modification_greater_than          = lookup(rule.value.actions.base_blob, "delete_after_days", null)
        }
      }
    }
  }
}
