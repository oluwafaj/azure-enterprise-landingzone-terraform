terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-platform-prod-01"
    storage_account_name = "sttfstatealzdc9f8027"
    container_name       = "tfstate"
    key                  = "workload-orders-prod.tfstate"
    use_oidc             = false
    use_azuread_auth     = true
  }
}
