locals {
  location = "eastus"

  common_tags = {
    environment = "lab"
    project     = "hybrid-enterprise"
    managed_by  = "terraform"
    lifecycle   = "ephemeral"
  }
}