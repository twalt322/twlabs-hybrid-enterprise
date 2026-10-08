resource "azurerm_resource_group" "hybrid" {
  name     = "rg-hybrid-enterprise"
  location = local.location

  tags = local.common_tags
}