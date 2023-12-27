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
resource "kubernetes_namespace_v1" "default" {
  metadata {
    name   = var.app
    labels = {
      app = var.app
    }
  }
}

# Create the Kubernetes deployment.
resource "kubernetes_deployment_v1" "default" {
  metadata {
    name      = var.app
    namespace = kubernetes_namespace_v1.default.metadata[0].name
    labels    = {
      app = var.app
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.app
      }
    }

    template {
      metadata {
        labels = {
          app = var.app
        }
      }

      spec {
        container {
          image = var.image
          name  = var.app

          port {
            container_port = 3000
            protocol       = "TCP"
          }

          env {
            name  = "NEXT_PUBLIC_COSMOS_DB_ENDPOINT"
            value = azurerm_cosmosdb_account.default.endpoint
          }

          env {
            name  = "NEXT_PUBLIC_COSMOS_DB_KEY"
            value = azurerm_cosmosdb_account.default.primary_key
          }

          env {
            name  = "NEXT_PUBLIC_COSMOS_DB_CONTAINER_ID"
            value = azurerm_cosmosdb_sql_database.default.id
          }

          env {
            name  = "NEXT_PUBLIC_COSMOS_DB_DATABASE_ID"
            value = azurerm_cosmosdb_sql_container.default.id
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

            initial_delay_seconds = 10
          }
        }
      }
    }
  }
}

# Create the Kubernetes service.
resource "kubernetes_service_v1" "default" {
  metadata {
    name      = var.app
    namespace = kubernetes_namespace_v1.default.metadata[0].name
    labels    = {
      app = var.app
    }
  }

  spec {
    selector = {
      app = var.app
    }

    port {
      port        = 3000
      target_port = 3000
    }
  }
}

# Create the ingress.
resource "kubernetes_ingress_v1" "default" {
  metadata {
    name      = var.app
    namespace = kubernetes_namespace_v1.default.metadata[0].name
    labels    = {
      app = var.app
    }
  }

  spec {
    rule {
      host = "santa.20.123.4.196.nip.io"

      http {
        path {
          backend {
            service {
              name = var.app
              port {
                number = 3000
              }
            }
          }

          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}
