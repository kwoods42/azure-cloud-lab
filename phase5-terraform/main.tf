# NOTE: Phase 5 VMs were provisioned manually via the Azure Portal as part of
# the learning process. This Terraform configuration documents the intended
# infrastructure as code and can be used to rebuild the environment from
# scratch. Existing VMs are not managed by this config to avoid disrupting
# the live AD environment (lab.local).

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-lab-terraform"
    storage_account_name = "stlabterraformstate"
    container_name       = "tfstate"
    key                  = "phase5.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

data "azurerm_resource_group" "lab" {
  name = "rg-lab-terraform"
}

data "azurerm_virtual_network" "lab" {
  name                = "vnet-lab-terraform"
  resource_group_name = data.azurerm_resource_group.lab.name
}

data "azurerm_subnet" "servers" {
  name                 = "snet-servers"
  virtual_network_name = data.azurerm_virtual_network.lab.name
  resource_group_name  = data.azurerm_resource_group.lab.name
}

data "azurerm_network_security_group" "lab" {
  name                = "nsg-lab-servers"
  resource_group_name = data.azurerm_resource_group.lab.name
}

resource "azurerm_public_ip" "dc02" {
  name                = "pip-lab-dc02"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc02" {
  name                = "nic-lab-dc02"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.1.6"
    public_ip_address_id          = azurerm_public_ip.dc02.id
  }
}

resource "azurerm_network_interface_security_group_association" "dc02" {
  network_interface_id      = azurerm_network_interface.dc02.id
  network_security_group_id = data.azurerm_network_security_group.lab.id
}

resource "azurerm_windows_virtual_machine" "dc02" {
  name                = "vm-lab-dc02"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = "Standard_D2s_v7"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  secure_boot_enabled               = true
  vtpm_enabled                      = true
  vm_agent_platform_updates_enabled = true
  zone                              = "1"

  network_interface_ids = [azurerm_network_interface.dc02.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "fs01" {
  name                = "pip-lab-fs01"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "fs01" {
  name                = "nic-lab-fs01"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fs01.id
  }
}

resource "azurerm_network_interface_security_group_association" "fs01" {
  network_interface_id      = azurerm_network_interface.fs01.id
  network_security_group_id = data.azurerm_network_security_group.lab.id
}

resource "azurerm_windows_virtual_machine" "fs01" {
  name                = "vm-lab-fs01"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = "Standard_D2s_v7"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  secure_boot_enabled               = true
  vtpm_enabled                      = true
  vm_agent_platform_updates_enabled = true
  zone                              = "1"

  network_interface_ids = [azurerm_network_interface.fs01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "app01" {
  name                = "pip-lab-app01"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "app01" {
  name                = "nic-lab-app01"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app01.id
  }
}

resource "azurerm_network_interface_security_group_association" "app01" {
  network_interface_id      = azurerm_network_interface.app01.id
  network_security_group_id = data.azurerm_network_security_group.lab.id
}

resource "azurerm_windows_virtual_machine" "app01" {
  name                = "vm-lab-app01"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = "Standard_D2s_v7"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  secure_boot_enabled               = true
  vtpm_enabled                      = true
  vm_agent_platform_updates_enabled = true
  zone                              = "1"

  network_interface_ids = [azurerm_network_interface.app01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "app02" {
  name                = "pip-lab-app02"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "app02" {
  name                = "nic-lab-app02"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app02.id
  }
}

resource "azurerm_network_interface_security_group_association" "app02" {
  network_interface_id      = azurerm_network_interface.app02.id
  network_security_group_id = data.azurerm_network_security_group.lab.id
}

resource "azurerm_windows_virtual_machine" "app02" {
  name                = "vm-lab-app02"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  size                = "Standard_D2lds_v7"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  secure_boot_enabled               = true
  vtpm_enabled                      = true
  vm_agent_platform_updates_enabled = true
  zone                              = "1"

  network_interface_ids = [azurerm_network_interface.app02.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

output "dc02_public_ip" {
  value = azurerm_public_ip.dc02.ip_address
}

output "fs01_public_ip" {
  value = azurerm_public_ip.fs01.ip_address
}

output "app01_public_ip" {
  value = azurerm_public_ip.app01.ip_address
}

output "app02_public_ip" {
  value = azurerm_public_ip.app02.ip_address
}
