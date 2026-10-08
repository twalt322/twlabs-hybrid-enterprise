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

  tags = local.common_tags
}