data "terraform_remote_state" "foundation" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstatecrtcw"
    container_name       = "tfstate"
    key                  = "twlabs.foundation.tfstate"
  }
}