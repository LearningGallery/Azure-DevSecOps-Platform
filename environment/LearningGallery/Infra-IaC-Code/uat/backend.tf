terraform {
  backend "azurerm" {
    #resource_group_name  = "rgsuiamgmtfm01"
    #storage_account_name = "stguiamgmtfm01"
    #container_name       = "tfstate"
    resource_group_name  = "TerraformInfraDevOps"
    storage_account_name = "terraforminfradevops"
    container_name       = "terraformstatefiles"
    key                  = "uat/devsecops.tfstate"
  }
}
