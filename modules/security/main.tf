# Read NSG rules from CSV
data "http" "myip" { url = "https://ipv4.icanhazip.com" }

locals {
  nsg_rules_csv = csvdecode(file(var.nsg_rules_csv_path))
}

# Network Security Groups
resource "azurerm_network_security_group" "nsgs" {
  for_each            = var.subnet_ids
  name                = "${each.key}nsg${var.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# NSG Rules from CSV
resource "azurerm_network_security_rule" "rules" {
  for_each = {
    for rule in local.nsg_rules_csv :
    "${rule.nsg_name}-${rule.rule_name}" => rule
  }

  name                        = each.value.rule_name
  priority                    = tonumber(each.value.priority)
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsgs[each.value.nsg_name].name
}

# NSG-Subnet Association
resource "azurerm_subnet_network_security_group_association" "associations" {
  for_each                  = var.subnet_ids
  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.nsgs[each.key].id
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "premium"

  enable_rbac_authorization       = true
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90
  public_network_access_enabled   = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = [chomp(data.http.myip.response_body), var.runner_ip != "" ? var.runner_ip : ""]
  }

  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "kv" {
  name                = "${var.key_vault_name}pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.key_vault_name}psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-group"
    private_dns_zone_ids = [var.key_vault_dns_zone_id]
  }

  tags = var.tags
}

# Role Assignment (Current User)
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.current_user_object_id
}
