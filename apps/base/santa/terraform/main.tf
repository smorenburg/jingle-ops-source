terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }
  }
}

provider "azurerm" {
  subscription_id      = "ae9db8ac-2682-4a98-ad36-7d13b2bd5a24"
  tenant_id            = "7ddc4c97-c5a0-4a29-ac83-59be0f280518"
  client_id            = "a28e49e2-df12-4271-b00b-529acb7a5401"
  use_oidc             = true
  oidc_token_file_path = "/var/run/secrets/azure/tokens/azure-identity-token"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-santa"
  location = "northeurope"
}
