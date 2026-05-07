terraform {
  backend "azurerm" {
    resource_group_name  = "rgspiamgmtfm01"
    storage_account_name = "stgpiamgmtfm01"
    container_name       = "tfstate"
    key                  = "prod/devsecops.tfstate"
  }
}

