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
    key                  = "lab.terraform.tfstate"
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
  tenant_id       = var.tenant_id
  # client_secret is set via ARM_CLIENT_SECRET environment variable
  # pulled from Key Vault at shell init — see README
}

data "azurerm_key_vault" "lab" {
  name                = "kv-lab-terraform"
  resource_group_name = "rg-lab-terraform"
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = "admin-password"
  key_vault_id = data.azurerm_key_vault.lab.id
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-lab-terraform"
  location = "East US"
  tags     = { environment = "lab" }
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-lab-terraform"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/16"]
  tags                = { environment = "lab" }
}

resource "azurerm_subnet" "servers" {
  name                 = "snet-servers"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.20.2.0/26"]
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-lab-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = { environment = "lab" }
}

resource "azurerm_bastion_host" "lab" {
  name                = "bastion-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tunneling_enabled   = true
  tags                = { environment = "lab" }

  ip_configuration {
    name                 = "bastion_ip_config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}


resource "azurerm_network_security_group" "lab" {
  name                = "nsg-lab-servers"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = { environment = "lab" }
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSQL"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "dc01" {
  name                = "nic-lab-dc01"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = { environment = "lab" }
}

resource "azurerm_network_interface_security_group_association" "dc01" {
  network_interface_id      = azurerm_network_interface.dc01.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "vm-lab-dc01-tf"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = "Standard_D2s_v7"
  admin_username      = var.admin_username
  admin_password      = data.azurerm_key_vault_secret.admin_password.value

  network_interface_ids = [azurerm_network_interface.dc01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
  vm_agent_platform_updates_enabled = true
  tags                              = { environment = "lab" }
}

resource "azurerm_network_interface" "lx01" {
  name                = "nic-lab-lx01"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = { environment = "lab" }
}

resource "azurerm_network_interface_security_group_association" "lx01" {
  network_interface_id      = azurerm_network_interface.lx01.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_linux_virtual_machine" "lx01" {
  name                = "vm-lab-lx01-tf"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = "Standard_D2s_v7"
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.lx01.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  lifecycle {
    ignore_changes = [admin_ssh_key]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  tags = { environment = "lab" }
}

resource "azurerm_key_vault" "lab" {
  name                      = "kv-lab-terraform"
  location                  = azurerm_resource_group.lab.location
  resource_group_name       = azurerm_resource_group.lab.name
  tenant_id                 = var.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  tags                      = { environment = "lab" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-lab-eastus"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = { environment = "lab" }
}

resource "azurerm_monitor_action_group" "lab" {
  name                = "ag-lab-alerts"
  resource_group_name = azurerm_resource_group.lab.name
  short_name          = "lab-alerts"
  tags                = { environment = "lab" }

  email_receiver {
    name          = "admin"
    email_address = "kev.woods42@gmail.com"
  }
}

resource "azurerm_monitor_metric_alert" "vm_unavailable" {
  name                = "alert-vm-unavailable"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = ["/subscriptions/4ea2ed32-c912-439e-a987-900507dd3c49/resourceGroups/rg-lab-terraform/providers/Microsoft.Compute/virtualMachines/vm-lab-dc01-tf"]
  severity            = 2
  window_size         = "PT5M"
  frequency           = "PT1M"
  description         = "Alert when VM CPU drops to zero - possible unplanned deallocation"
  auto_mitigate       = false
  tags                = { environment = "lab" }

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = "/subscriptions/4ea2ed32-c912-439e-a987-900507dd3c49/resourceGroups/rg-lab-terraform/providers/microsoft.insights/actionGroups/ag-lab-alerts"
  }
}
