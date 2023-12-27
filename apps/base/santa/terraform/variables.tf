variable "app" {
  description = "Optional. The name of the application."
  type        = string
  default     = "santa"
}

variable "location" {
  description = "Optional. The location (region) for the resources."
  type        = string
  default     = "northeurope"
}

variable "location_abbreviation" {
  description = "Optional. The abbreviation of the location."
  type        = map(string)
  default     = {
    "westeurope"  = "weu"
    "northeurope" = "neu"
    "eastus"      = "eus"
    "westus"      = "wus"
    "ukwest"      = "ukw"
    "uksouth"     = "uks"
  }
}

variable "environment" {
  description = "Required. The environment for the resources."
  type        = string
}

variable "environment_abbreviation" {
  description = "Optional. The abbreviation of the environment."
  type        = map(string)
  default     = {
    "development" = "dev"
    "staging"     = "stage"
    "production"  = "prod"
  }
}

variable "image" {
  description = "Required. The image for the container."
  type        = string
}
