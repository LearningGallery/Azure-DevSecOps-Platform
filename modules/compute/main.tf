# Read infrastructure config from CSV
locals {
  infra_csv = csvdecode(file(var.infrastructure_csv_path))
  linux_vms = [for row in local.infra_csv : row if row.os_type == "Linux"]
  windows_vms = [for row in local.infra_csv : row if row.os_type == "Windows"]
}

# Linux Bootstrap Servers (Ubuntu 24.04)
resource "azurerm_linux_virtual_machine" "linux" {
  for_each = { for vm in local.linux_vms : vm.name => vm }

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.vm_size
  admin_username      = "azureuser"

  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  network_interface_ids = [azurerm_network_interface.linux[each.key].id]

  os_disk {
    name                 = "${each.value.name}osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(file(var.linux_bootstrap_script_path))

  tags = var.tags
}

# Linux Network Interfaces (NO Public IP)
resource "azurerm_network_interface" "linux" {
  for_each            = { for vm in local.linux_vms : vm.name => vm }
  name                = "${each.value.name}nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.compute_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Linux Managed Data Disks
resource "azurerm_managed_disk" "linux_data" {
  for_each = { for vm in local.linux_vms : vm.name => vm }

  name                 = "${each.value.name}datadisk01"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = tonumber(each.value.data_disk_size_gb)

  tags = var.tags
}

# Attach Data Disks to Linux VMs
resource "azurerm_virtual_machine_data_disk_attachment" "linux" {
  for_each = { for vm in local.linux_vms : vm.name => vm }

  managed_disk_id    = azurerm_managed_disk.linux_data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.linux[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}

# Windows Bootstrap Servers (Server 2022)
resource "azurerm_windows_virtual_machine" "windows" {
  for_each = { for vm in local.windows_vms : vm.name => vm }

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.vm_size
  admin_username      = "azureadmin"
  admin_password      = var.windows_admin_password

  network_interface_ids = [azurerm_network_interface.windows[each.key].id]

  os_disk {
    name                 = "${each.value.name}osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Windows Network Interfaces (NO Public IP)
resource "azurerm_network_interface" "windows" {
  for_each            = { for vm in local.windows_vms : vm.name => vm }
  name                = "${each.value.name}nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.compute_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Windows Managed Data Disks
resource "azurerm_managed_disk" "windows_data" {
  for_each = { for vm in local.windows_vms : vm.name => vm }

  name                 = "${each.value.name}datadisk01"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = tonumber(each.value.data_disk_size_gb)

  tags = var.tags
}

# Attach Data Disks to Windows VMs
resource "azurerm_virtual_machine_data_disk_attachment" "windows" {
  for_each = { for vm in local.windows_vms : vm.name => vm }

  managed_disk_id    = azurerm_managed_disk.windows_data[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.windows[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}

# Windows Custom Script Extension (Bootstrap)
resource "azurerm_virtual_machine_extension" "windows_bootstrap" {
  for_each = { for vm in local.windows_vms : vm.name => vm }

  name                 = "bootstrap"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(file(var.windows_bootstrap_script_path), "UTF-16LE")}"
  })

  tags = var.tags
}
