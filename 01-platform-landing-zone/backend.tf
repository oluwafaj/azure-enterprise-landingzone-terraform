terraform {
  backend "azurerm" {
    # Populate these values from 00-bootstrap/bootstrap.sh output
    resource_group_name  = "rg-tfstate-platform-prod-01"
    storage_account_name = "sttfstatealzdc9f8027"
    container_name       = "tfstate"
    key                  = "platform-alz.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}
