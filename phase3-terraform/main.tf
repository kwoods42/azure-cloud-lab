terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-lab-terraform"
    storage_account_name = "stlabtfstate2026"
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

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-lab-servers"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = { environment = "lab" }

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
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
  name                  = "vm-lab-dc01-tf"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = "Standard_D2s_v7"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
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
  tags = { environment = "lab" }
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
  name                  = "vm-lab-lx01-tf"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = "Standard_D2s_v7"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.lx01.id]
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
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
    email_address = "KevinWoods@TBGWorks.onmicrosoft.com"
  }
}

resource "azurerm_monitor_metric_alert" "vm_unavailable" {
  name                = "alert-vm-unavailable"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = ["/subscriptions/${var.subscription_id}/resourceGroups/rg-lab-terraform/providers/Microsoft.Compute/virtualMachines/vm-lab-dc01-tf"]
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
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

resource "azurerm_private_dns_zone" "lab_local" {
  name                = "lab.local"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = { environment = "lab" }
}

resource "azurerm_private_dns_zone_virtual_network_link" "lab_local" {
  name                  = "link-lab-local-vnet"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.lab_local.name
  virtual_network_id    = azurerm_virtual_network.lab.id
  registration_enabled  = false
  tags                  = { environment = "lab" }
}

resource "azurerm_private_dns_a_record" "dc02" {
  name                = "vm-lab-dc02"
  zone_name           = azurerm_private_dns_zone.lab_local.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 3600
  records             = ["10.20.1.6"]
  tags                = { environment = "lab" }
}

resource "azurerm_private_dns_a_record" "fs01" {
  name                = "vm-lab-fs01"
  zone_name           = azurerm_private_dns_zone.lab_local.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 3600
  records             = ["10.20.1.7"]
  tags                = { environment = "lab" }
}

resource "azurerm_private_dns_a_record" "app01" {
  name                = "vm-lab-app01"
  zone_name           = azurerm_private_dns_zone.lab_local.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 3600
  records             = ["10.20.1.8"]
  tags                = { environment = "lab" }
}

resource "azurerm_private_dns_a_record" "app02" {
  name                = "vm-lab-app02"
  zone_name           = azurerm_private_dns_zone.lab_local.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 3600
  records             = ["10.20.1.9"]
  tags                = { environment = "lab" }
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = { environment = "lab" }
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "link-lab-keyvault-vnet"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.lab.id
  registration_enabled  = false
  tags                  = { environment = "lab" }
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-lab-keyvault"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.servers.id
  tags                = { environment = "lab" }
  private_service_connection {
    name                           = "conn-lab-keyvault"
    private_connection_resource_id = azurerm_key_vault.lab.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
  private_dns_zone_group {
    name                 = "keyvault-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-lab-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
  tags                = { environment = "lab" }
}

resource "azurerm_subnet" "bastion_hub" {
  name                            = "AzureBastionSubnet"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.hub.name
  address_prefixes                = ["10.30.1.0/26"]
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "bastion_hub" {
  name                = "pip-hub-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = { environment = "lab" }
}

resource "azurerm_bastion_host" "hub" {
  name                = "bastion-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tunneling_enabled   = true
  tags                = { environment = "lab" }
  ip_configuration {
    name                 = "bastion_ip_config"
    subnet_id            = azurerm_subnet.bastion_hub.id
    public_ip_address_id = azurerm_public_ip.bastion_hub.id
  }
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.lab.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.lab.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
