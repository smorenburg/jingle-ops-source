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
  client_id            = "223b377c-bb9b-499c-9c9e-106b95d7c628"
  use_oidc             = true
  oidc_token_file_path = "/var/run/secrets/azure/tokens/azure-identity-token"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  # Set the application name
  app = "santa"

  # Lookup and set the location abbreviation, defaults to na (not available).
  location_abbreviation = try(var.location_abbreviation[var.location], "na")

  # Lookup and set the environment abbreviation, defaults to na (not available).
  environment_abbreviation = try(var.environment_abbreviation[var.environment], "na")

  # Construct the name suffix.
  suffix = "${local.app}-${local.environment_abbreviation}-${local.location_abbreviation}"
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}
