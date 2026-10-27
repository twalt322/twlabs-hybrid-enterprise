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

  shared_key = data.azurerm_key_vault_secret.vpn_shared_key.value

  tags = local.common_tags
}

module "compute" {
  source = "../modules/compute"

  resource_group_name  = data.terraform_remote_state.foundation.outputs.resource_group_name
  location             = data.terraform_remote_state.foundation.outputs.location
  vmss_name            = "vmss-twlabs-workload"
  vm_size              = "Standard_D2alds_v7"
  instance_count       = 2
  subnet_id            = data.terraform_remote_state.foundation.outputs.workload_subnet_id
  admin_username       = "twlabsadmin"
  admin_ssh_public_key = file("~/.ssh/twlabs_hybrid_vmss.pub")

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.vmss.id
  ]

  tags = local.common_tags
}

resource "azurerm_role_assignment" "vmss_acr_pull" {
  scope                = data.terraform_remote_state.foundation.outputs.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.compute.principal_id
}

resource "azurerm_role_assignment" "vmss_key_vault_secrets_user" {
  scope                = data.terraform_remote_state.foundation.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.compute.principal_id
}

resource "azurerm_lb" "internal" {
  name                = "lb-twlabs-internal"
  location            = data.terraform_remote_state.foundation.outputs.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal-frontend"
    subnet_id                     = data.terraform_remote_state.foundation.outputs.workload_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.40.100"
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "vmss" {
  name            = "backend-vmss"
  loadbalancer_id = azurerm_lb.internal.id
}

resource "azurerm_lb_probe" "http" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.internal.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.internal.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_probe" "https" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "probe-https"
  port            = 443
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.internal.id
  name                           = "rule-https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.https.id
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-gateway"
  location            = local.location
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]

  tags = local.common_tags
}

resource "azurerm_nat_gateway" "nat" {
  name                    = "ng-twlabs-hybrid"
  location                = local.location
  resource_group_name     = data.terraform_remote_state.foundation.outputs.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]

  tags = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_pip" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_snet" {
  subnet_id      = data.terraform_remote_state.foundation.outputs.workload_subnet_id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}