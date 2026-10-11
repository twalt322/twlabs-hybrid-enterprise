resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vng-twlabs-hybrid"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  bgp_enabled   = false

  sku = "VpnGw1AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = data.terraform_remote_state.foundation.outputs.vpn_public_ip_id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.gateway_subnet_id
  }

  tags = local.common_tags
}

resource "azurerm_local_network_gateway" "home" {
  name                = "lng-twlabs-home"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name

  gateway_address = var.home_public_ip

  address_space = [
    "192.168.40.0/24"
  ]

  tags = local.common_tags
}

resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                = "conn-twlabs-s2s"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.home.id

  shared_key = var.vpn_shared_key

  tags = local.common_tags
}