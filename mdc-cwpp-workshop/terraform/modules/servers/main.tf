variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "allowed_source_cidr" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-mdc"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "vm" {
  name                 = "vm"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_subnet" "attacker" {
  name                 = "attacker"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.2.0/24"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.10.0/23"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "allow-rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }
}

# ----- Windows VM -----
resource "azurerm_public_ip" "win" {
  name                = "pip-winvm"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "win" {
  name                = "nic-winvm"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win.id
  }
}

resource "azurerm_network_interface_security_group_association" "win" {
  network_interface_id      = azurerm_network_interface.win.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "win" {
  name                  = "vm-win-mdc"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2s_v5"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.win.id]
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "win_mde" {
  name                 = "MDE.Windows"
  virtual_machine_id   = azurerm_windows_virtual_machine.win.id
  publisher            = "Microsoft.Azure.AzureDefenderForServers"
  type                 = "MDE.Windows"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

resource "azurerm_virtual_machine_extension" "win_ama" {
  name                 = "AzureMonitorWindowsAgent"
  virtual_machine_id   = azurerm_windows_virtual_machine.win.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorWindowsAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
}

# ----- Linux VM -----
resource "azurerm_public_ip" "lin" {
  name                = "pip-linuxvm"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "lin" {
  name                = "nic-linuxvm"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lin.id
  }
}

resource "azurerm_network_interface_security_group_association" "lin" {
  network_interface_id      = azurerm_network_interface.lin.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "lin" {
  name                            = "vm-lin-mdc"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = "Standard_D2s_v5"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.lin.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "lin_mde" {
  name                 = "MDE.Linux"
  virtual_machine_id   = azurerm_linux_virtual_machine.lin.id
  publisher            = "Microsoft.Azure.AzureDefenderForServers"
  type                 = "MDE.Linux"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

resource "azurerm_virtual_machine_extension" "lin_ama" {
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.lin.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
}

output "vnet_id"           { value = azurerm_virtual_network.vnet.id }
output "aks_subnet_id"     { value = azurerm_subnet.aks.id }
output "windows_public_ip" { value = azurerm_public_ip.win.ip_address }
output "linux_public_ip"   { value = azurerm_public_ip.lin.ip_address }
