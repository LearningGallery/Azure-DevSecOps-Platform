# Read subnets from CSV
locals {
  subnets_csv = csvdecode(file(var.subnets_csv_path))
  subnets = {
    for row in local.subnets_csv :
    row.name => {
      name              = row.name
      address_prefixes  = [row.address_prefix]
      service_endpoints = row.service_endpoints != "" ? split(",", row.service_endpoints) : []
      delegation        = row.delegation != "" ? row.delegation : null
    }
  }
}

# VNet
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "subnets" {
  for_each             = local.subnets
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  private_endpoint_network_policies = "Disabled"

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [1] : []
    content {
      name = "delegation"
      service_delegation {
        name    = each.value.delegation
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# NAT Gateway (for outbound without Public IPs on VMs)
resource "azurerm_public_ip" "nat" {
  name                = var.nat_gateway_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                = var.nat_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "main" {
  for_each       = azurerm_subnet.subnets
  subnet_id      = each.value.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# Private DNS Zones (Azure Monitor, Storage, Key Vault)
resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = azurerm_private_dns_zone.zones
  name                  = "${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.tags
}

# Azure Bastion (Developer Tier) - Conditionally Deployed
resource "azurerm_bastion_host" "main" {
  count               = var.enable_bastion ? 1 : 0
  
  name                = var.bastion_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Developer"
  virtual_network_id  = azurerm_virtual_network.main.id

  depends_on = [
    azurerm_virtual_network.main
  ]

  tags = var.tags
}
