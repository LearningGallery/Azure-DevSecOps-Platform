output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "nsg_ids" {
  value = { for k, v in azurerm_network_security_group.nsgs : k => v.id }
}
