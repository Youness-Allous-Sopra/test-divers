terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.30.0"
    }
  }

  /* backend "azurerm" {
    resource_group_name  = "lz-terraform-state"
    storage_account_name = "lzmrstfstate"
    container_name       = "tfstate"
    use_azuread_auth     = false
    subscription_id      = "eceb7ec9-bb17-4351-842c-90e14f45ca5e" # Hub
    tenant_id            = "b1e9317b-8655-4923-aeba-8c08739d8a40" 
    #key                  = "EnvDev.terraform.tfstate"            # a commenter et renseigner dans pipeline si code execute par github actions
  } */
}

# Define the provider configuration
provider "azurerm" {
  features {}
  #subscription_id = "a9fb635c-fcae-484c-8651-6bf07653f825" #Spoke DEV, a commenter si code execute par github actions
}

# provider "azurerm" {
#   alias = "hub"
#   subscription_id = "eceb7ec9-bb17-4351-842c-90e14f45ca5e"
#   features {}
# }


# Recuperation des infos de ressources deja existantes
# data "azurerm_client_config" "current" {}

# data "azurerm_virtual_network" "vnet_hub" {
#   provider            = azurerm.hub 
#   name                = "lz-hub-francecentral"
#   resource_group_name = "lz-connectivity-francecentral"
# }

# data "azurerm_firewall" "firewall" {
#   provider            = azurerm.hub 
#   name                = "lz-fw-francecentral"
#   resource_group_name = "lz-connectivity-francecentral"
# }