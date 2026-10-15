output "principal_id" {
  value = azurerm_linux_virtual_machine_scale_set.workload.identity[0].principal_id
}