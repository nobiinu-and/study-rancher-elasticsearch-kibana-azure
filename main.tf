variable "default_user" {}
variable "default_password" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

variable "location" {
  default = "Japan West"
}

variable "server_vm_size" {
  default = "Standard_A1_v2"
}

variable "agent_vm_size" {
  default = "Standard_D1_v2"
}

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

resource "azurerm_resource_group" "test" {
  name     = "RancherESK"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "test" {
  name                = "RancherESK-base-vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
  name                 = "RancherESK-base-sub"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.2.0/24"
}

module "rancher_server" {
  source              = "./rancher-server"
  name                = "RancherESK-server"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  subnet_id           = "${azurerm_subnet.test.id}"

  vm_size = "${var.server_vm_size}"

  default_user     = "${var.default_user}"
  default_password = "${var.default_password}"
}

module "rancher_agent_01" {
  source              = "./rancher-agent"
  name                = "RancherESK-agent-01"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  subnet_id           = "${azurerm_subnet.test.id}"

  vm_size = "${var.agent_vm_size}"

  default_user     = "${var.default_user}"
  default_password = "${var.default_password}"
}

module "rancher_agent_02" {
  source              = "./rancher-agent"
  name                = "RancherESK-agent-02"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  subnet_id           = "${azurerm_subnet.test.id}"

  vm_size = "${var.agent_vm_size}"

  default_user     = "${var.default_user}"
  default_password = "${var.default_password}"
}
