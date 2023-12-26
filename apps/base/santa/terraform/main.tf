terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }
    kubernetes = {
      version = ">= 2.24"
    }
  }
}

provider "kubernetes" {}

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
    namespace = kubernetes_namespace.default.metadata.name
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
    namespace = kubernetes_namespace.default.metadata.name
    labels = {
      app = "santa"
    }
  }
  spec {
    selector = {
      app = "santa"
    }

    port {
      port        = 8080
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
