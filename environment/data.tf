data "terraform_remote_state" "foundation" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstatecrtcw"
    container_name       = "tfstate"
    key                  = "twlabs.foundation.tfstate"
  }
}

data "azurerm_key_vault_secret" "vpn_shared_key" {
  name         = "vpn-shared-key"
  key_vault_id = data.terraform_remote_state.foundation.outputs.key_vault_id
}