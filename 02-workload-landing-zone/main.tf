# ------------------------------------------------------------------------------
# 1. Read Platform Outputs via Remote State (Decoupled Architecture)
# ------------------------------------------------------------------------------
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = "tfstate"
    key                  = "platform-alz.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

data "azurerm_client_config" "current" {}

locals {
  base_name = "${var.workload_name}-${var.environment}-${var.location}"
  tags = {
    Environment = title(var.environment)
    Workload    = var.workload_name
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# 2. Workload Resource Group & Spoke Virtual Network
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "workload" {
  name     = "rg-${local.base_name}-01"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${local.base_name}-01"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  address_space       = var.spoke_vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.app_subnet_prefix]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.pe_subnet_prefix]
}

# ------------------------------------------------------------------------------
# 3. Hub-and-Spoke VNet Peering & Forced Tunneling (UDR to Azure Firewall)
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.workload.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = data.terraform_remote_state.platform.outputs.hub_vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.connectivity
  name                      = "peer-hub-to-${local.base_name}"
  resource_group_name       = data.terraform_remote_state.platform.outputs.hub_resource_group_name
  virtual_network_name      = data.terraform_remote_state.platform.outputs.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

resource "azurerm_route_table" "spoke_udr" {
  name                = "rt-${local.base_name}-01"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags

  route {
    name                   = "default-to-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = data.terraform_remote_state.platform.outputs.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "app_udr" {
  subnet_id      = azurerm_subnet.app.id
  route_table_id = azurerm_route_table.spoke_udr.id
}

# ------------------------------------------------------------------------------
# 4. Workload Identity & Private Key Vault (Zero Public Access)
# ------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${local.base_name}-01"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags
}

resource "azurerm_key_vault" "workload" {
  name                          = "kv-${var.workload_name}-${var.environment}-001"
  location                      = azurerm_resource_group.workload.location
  resource_group_name           = azurerm_resource_group.workload.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  tags                          = local.tags
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.workload.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-kv-${local.base_name}-01"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv-${local.base_name}"
    private_connection_resource_id = azurerm_key_vault.workload.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.terraform_remote_state.platform.outputs.keyvault_private_dns_zone_id]
  }
}

# ------------------------------------------------------------------------------
# 5. Diagnostic Settings -> Central Platform Log Analytics
# ------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-to-central-law"
  target_resource_id         = azurerm_key_vault.workload.id
  log_analytics_workspace_id = data.terraform_remote_state.platform.outputs.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
}
