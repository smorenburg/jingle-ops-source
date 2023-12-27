terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }
    random = {
      version = ">= 3.6"
    }
    kubernetes = {
      version = ">= 2.24"
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

# Generate a random suffix for the CosmosDB account.
resource "random_id" "cosmosdb" {
  byte_length = 3
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}

# Create the CosmosDB account, database, and container.
resource "azurerm_cosmosdb_account" "default" {
  name                      = "cosmos-${var.app}-${local.environment_abbreviation}-${random_id.cosmosdb.hex}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.default.name
  offer_type                = "Standard"
  enable_automatic_failover = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = "northeurope"
    failover_priority = 0
  }

  geo_location {
    location          = "westeurope"
    failover_priority = 1
  }
}

resource "azurerm_cosmosdb_sql_database" "default" {
  name                = "ftc23"
  resource_group_name = azurerm_resource_group.default.name
  account_name        = azurerm_cosmosdb_account.default.name

  autoscale_settings {
    max_throughput = "1000"
  }
}

resource "azurerm_cosmosdb_sql_container" "default" {
  name                = "persons"
  resource_group_name = azurerm_resource_group.default.name
  account_name        = azurerm_cosmosdb_account.default.name
  database_name       = azurerm_cosmosdb_sql_database.default.name
  partition_key_path  = "/definition/id"

  autoscale_settings {
    max_throughput = "1000"
  }
}

# Create the Kubernetes namespace.
resource "kubernetes_namespace" "default" {
  metadata {
    name = "santa"
    labels = {
      app = "santa"
    }
  }
}

# Create the Kubernetes deployment.
resource "kubernetes_deployment" "default" {
  metadata {
    name      = "santa"
    namespace = kubernetes_namespace.default.metadata[0].name
    labels = {
      app = "santa"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "santa"
      }
    }

    template {
      metadata {
        labels = {
          app = "santa"
        }
      }

      spec {
        container {
          image = "crjingle7d687c.azurecr.io/ftc2023:latest"
          name  = "santa"

          port {
            container_port = 3000
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }

            initial_delay_seconds = 3
          }
        }
      }
    }
  }
}

# Create the Kubernetes service.
resource "kubernetes_service" "default" {
  metadata {
    name      = "santa"
    namespace = kubernetes_namespace.default.metadata[0].name
    labels = {
      app = "santa"
    }
  }
  spec {
    selector = {
      app = "santa"
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}
