variable "name" {}
variable "location" {}
variable "resource_group_name" {}
variable "subnet_id" {}
variable "vm_size" {}
variable "default_user" {}
variable "default_password" {}

resource "azurerm_public_ip" "rancher_server" {
  name                         = "${var.name}-pi"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_security_group" "rancher_server" {
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
    name                       = "rancher"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "rancher_server" {
  name                      = "${var.name}-ni"
  location                  = "${var.location}"
  resource_group_name       = "${var.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.rancher_server.id}"

  ip_configuration {
    name                          = "${var.name}-ipconf"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.rancher_server.id}"
  }
}

resource "random_id" "rancher_server_storage_account" {
  byte_length = 10
}

resource "azurerm_storage_account" "rancher_server" {
  name                = "${random_id.rancher_server_storage_account.hex}"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"

  lifecycle {
    ignore_changes = ["name"]
  }
}

resource "azurerm_storage_container" "rancher_server" {
  name                  = "${lower(replace(var.name, "-", ""))}vhds"
  resource_group_name   = "${var.resource_group_name}"
  storage_account_name  = "${azurerm_storage_account.rancher_server.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "rancher_server" {
  name                  = "${var.name}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
  network_interface_ids = ["${azurerm_network_interface.rancher_server.id}"]
  vm_size               = "${var.vm_size}"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.name}-Disk01"
    vhd_uri       = "${azurerm_storage_account.rancher_server.primary_blob_endpoint}${azurerm_storage_container.rancher_server.name}/${var.name}-Disk01.vhd"
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

resource "azurerm_virtual_machine_extension" "rancher_server" {
  name                 = "docker"
  location             = "${var.location}"
  resource_group_name  = "${var.resource_group_name}"
  virtual_machine_name = "${azurerm_virtual_machine.rancher_server.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "DockerExtension"
  type_handler_version = "1.0"

  settings = <<SETTINGS
    {
        "compose": {
            "rancheragent": {
              "image": "rancher/server:stable",
              "restart": "always",
              "ports": [ "8080:8080" ]
            }
        }
    }
SETTINGS
}
