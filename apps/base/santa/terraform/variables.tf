variable "app" {
  description = "Required. The name of the application."
  type        = string
}

variable "location" {
  description = "Required. The location (region) for the resources."
  type        = string
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
