output "resource_group_name" {
  value = azurerm_resource_group.hybrid.name
}

output "location" {
  value = local.location
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "vnet_name" {
  value = module.networking.vnet_name
}

output "workload_subnet_id" {
  value = module.networking.workload_subnet_id
}

output "gateway_subnet_id" {
  value = module.networking.gateway_subnet_id
}

output "vpn_public_ip_id" {
  value = azurerm_public_ip.vpn.id
}

output "vpn_public_ip_address" {
  value = azurerm_public_ip.vpn.ip_address
}

output "key_vault_id" {
  value = azurerm_key_vault.hybrid.id
}

output "acr_login_server" {
  value = azurerm_container_registry.apps.login_server
}

output "acr_id" {
  value = azurerm_container_registry.apps.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}