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

# Create the CosmosDB account.
resource "azurerm_cosmosdb_account" "default" {
  name                = "cosmos-${var.app}-${local.environment_abbreviation}-${random_id.cosmosdb.hex}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_automatic_failover = true

  capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = "westeurope"
    failover_priority = 0
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
          image = "nginx:1.21.6"
          name  = "santa"

          port {
            container_port = 80
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
              port = 80
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
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
