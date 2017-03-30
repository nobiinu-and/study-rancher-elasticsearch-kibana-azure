variable "name" {}
variable "location" {}
variable "resource_group_name" {}
variable "subnet_id" {}
variable "vm_size" {}
variable "default_user" {}
variable "default_password" {}

resource "azurerm_public_ip" "rancher_agent" {
  name                         = "${var.name}-pi"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

/*
resource "azurerm_network_security_group" "rancher_agent" {
  name                = "${var.name}-nsg"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  security_rule = {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule = {
    name                       = "rancher-agent-500"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule = {
    name                       = "rancher-agent-4500"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}*/

resource "azurerm_network_interface" "rancher_agent" {
  name                = "${var.name}-ni"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  /*network_security_group_id = "${azurerm_network_security_group.rancher_agent.id}"*/

  ip_configuration {
    name                          = "${var.name}-ipconf"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.rancher_agent.id}"
  }
}

resource "random_id" "rancher_agent_storage_account" {
  byte_length = 10
}

resource "azurerm_storage_account" "rancher_agent" {
  name                = "${random_id.rancher_agent_storage_account.hex}"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"

  lifecycle {
    ignore_changes = ["name"]
  }
}

resource "azurerm_storage_container" "rancher_agent" {
  name                  = "${lower(replace(var.name, "-", ""))}vhds"
  resource_group_name   = "${var.resource_group_name}"
  storage_account_name  = "${azurerm_storage_account.rancher_agent.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "rancher_agent" {
  name                  = "${var.name}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
  network_interface_ids = ["${azurerm_network_interface.rancher_agent.id}"]
  vm_size               = "${var.vm_size}"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.name}-Disk01"
    vhd_uri       = "${azurerm_storage_account.rancher_agent.primary_blob_endpoint}${azurerm_storage_container.rancher_agent.name}/${var.name}-Disk01.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.name}"
    admin_username = "${var.default_user}"
    admin_password = "${var.default_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine_extension" "rancher_agent" {
  name                 = "docker"
  location             = "${var.location}"
  resource_group_name  = "${var.resource_group_name}"
  virtual_machine_name = "${azurerm_virtual_machine.rancher_agent.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "DockerExtension"
  type_handler_version = "1.0"
}
