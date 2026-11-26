provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.management_subscription_id
  use_oidc        = false
}

provider "azurerm" {
  alias = "connectivity"
  features {}
  subscription_id = var.connectivity_subscription_id
  use_oidc        = true
}

provider "azapi" {
  use_oidc = true
}
