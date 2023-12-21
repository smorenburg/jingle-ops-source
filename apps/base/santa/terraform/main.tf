terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  # Lookup and set the location abbreviation, defaults to na (not available).
  location_abbreviation = try(var.location_abbreviation[var.location], "na")

  # Lookup and set the environment abbreviation, defaults to na (not available).
  environment_abbreviation = try(var.environment_abbreviation[var.environment], "na")

  # Construct the name suffix.
  suffix = "${var.app}-${local.environment_abbreviation}-${local.location_abbreviation}"
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}
