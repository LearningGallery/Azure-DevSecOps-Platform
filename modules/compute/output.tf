output "linux_vm_ids" {
  value = { for k, v in azurerm_linux_virtual_machine.linux : k => v.id }
}

output "windows_vm_ids" {
  value = { for k, v in azurerm_windows_virtual_machine.windows : k => v.id }
}

output "linux_vm_private_ips" {
  value = { for k, v in azurerm_network_interface.linux : k => v.private_ip_address }
}

output "windows_vm_private_ips" {
  value = { for k, v in azurerm_network_interface.windows : k => v.private_ip_address }
}
