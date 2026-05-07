terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0.1"
    }
  }
}
