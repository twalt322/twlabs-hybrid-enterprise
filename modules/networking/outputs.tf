output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "workload_subnet_id" {
  value = azurerm_subnet.workload.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}