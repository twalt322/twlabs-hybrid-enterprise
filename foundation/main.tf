data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "hybrid" {
  name     = "rg-hybrid-enterprise"
  location = local.location

  tags = local.common_tags
}

module "networking" {
  source = "../modules/networking"

  resource_group_name = azurerm_resource_group.hybrid.name
  location            = local.location

  vnet_name                = "vnet-twlabs-hybrid"
  vnet_address_space       = ["10.0.40.0/24"]
  workload_subnet_name     = "snet-workload"
  workload_subnet_prefixes = ["10.0.40.0/25"]
  gateway_subnet_name      = "GatewaySubnet"
  gateway_subnet_prefixes  = ["10.0.40.128/27"]
  nsg_name                 = "nsg-snet-workload"
  dns_servers              = ["192.168.40.10"]
  onprem_address_space     = "192.168.40.0/24"
  dns_server_ip            = "192.168.40.10"

  tags = local.common_tags
}

resource "azurerm_public_ip" "vpn" {
  name                = "pip-vpn-gateway"
  location            = local.location
  resource_group_name = azurerm_resource_group.hybrid.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_key_vault" "hybrid" {
  name                = "kv-twlabs-hybrid"
  location            = local.location
  resource_group_name = azurerm_resource_group.hybrid.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                   = "standard"
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.common_tags
}

resource "azurerm_container_registry" "apps" {
  name                = "acrtwlabsapps"
  resource_group_name = azurerm_resource_group.hybrid.name
  location            = local.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = local.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-twlabs-hybrid"
  location            = local.location
  resource_group_name = azurerm_resource_group.hybrid.name

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = local.common_tags
}