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
resource "random_id" "redis" {
  byte_length = 3
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}

# Create the Azure Cache for Redis.
resource "azurerm_redis_cache" "default" {
  name                = "redis-${var.app}-${local.environment_abbreviation}-${random_id.redis.hex}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = true
  minimum_tls_version = "1.2"
}

# Create the Kubernetes namespace.
resource "kubernetes_namespace_v1" "default" {
  metadata {
    name = var.app

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

    labels = {
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
          image = var.container_image
          name  = var.app

          port {
            container_port = 80
            protocol       = "TCP"
          }

          env {
            name  = "REDIS"
            value = azurerm_redis_cache.default.hostname
          }

          env {
            name  = "REDIS_PWD"
            value = azurerm_redis_cache.default.primary_access_key
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

    labels = {
      app = var.app
    }
  }

  spec {
    selector = {
      app = var.app
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

# Create the ingress.
resource "kubernetes_ingress_v1" "default" {
  metadata {
    name      = var.app
    namespace = kubernetes_namespace_v1.default.metadata[0].name

    labels = {
      app = var.app
    }

    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"
    }
  }

  spec {
    tls {
      hosts       = [var.ingress_rule_host]
      secret_name = "tls-secret"
    }

    rule {
      host = var.ingress_rule_host

      http {
        path {
          backend {
            service {
              name = var.app
              port {
                number = 80
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
