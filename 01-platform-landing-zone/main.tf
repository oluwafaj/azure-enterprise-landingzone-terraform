# ------------------------------------------------------------------------------
# 1. Management Group Hierarchy (ALZ Standard Pattern)
# ------------------------------------------------------------------------------
resource "azurerm_management_group" "root_org" {
  display_name               = "${upper(var.prefix)} Enterprise"
  name                       = "${var.prefix}-root"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.root_parent_management_group_id}"
}

resource "azurerm_management_group" "platform" {
  display_name               = "Platform"
  name                       = "${var.prefix}-platform"
  parent_management_group_id = azurerm_management_group.root_org.id
}

resource "azurerm_management_group" "platform_management" {
  display_name               = "Management"
  name                       = "${var.prefix}-platform-management"
  parent_management_group_id = azurerm_management_group.platform.id
  subscription_ids           = [var.management_subscription_id]
}

resource "azurerm_management_group" "platform_connectivity" {
  display_name               = "Connectivity"
  name                       = "${var.prefix}-platform-connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "landing_zones" {
  display_name               = "Landing Zones"
  name                       = "${var.prefix}-landing-zones"
  parent_management_group_id = azurerm_management_group.root_org.id
}

resource "azurerm_management_group" "lz_corp" {
  display_name               = "Corp (Connected)"
  name                       = "${var.prefix}-lz-corp"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

# ------------------------------------------------------------------------------
# 2. Baseline Azure Policy Guardrails (Audit-first approach)
# ------------------------------------------------------------------------------
resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Azure Regions"
  management_group_id  = azurerm_management_group.root_org.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  enforce              = true

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [var.location, "ukwest"]
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_env_tag" {
  name                 = "audit-env-tag"
  display_name         = "Audit Missing Environment Tag on Resource Groups"
  management_group_id  = azurerm_management_group.landing_zones.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  enforce              = false # Set to false initially for safe Audit rollout

  parameters = jsonencode({
    tagName = {
      value = "Environment"
    }
  })
}

# ------------------------------------------------------------------------------
# 3. Central Management & Observability (Log Analytics)
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "management" {
  name     = "rg-${var.prefix}-mgmt-${var.location}-01"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "central" {
  name                = "law-${var.prefix}-central-${var.location}-01"
  location            = azurerm_resource_group.management.location
  resource_group_name = azurerm_resource_group.management.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# 4. Hub Networking & Shared Private DNS (Connectivity Subscription)
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "connectivity" {
  provider = azurerm.connectivity
  name     = "rg-${var.prefix}-hub-${var.location}-01"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  provider            = azurerm.connectivity
  name                = "vnet-${var.prefix}-hub-${var.location}-01"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = var.hub_vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  provider             = azurerm.connectivity
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_subnet" "bastion" {
  provider             = azurerm.connectivity
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_public_ip" "firewall" {
  provider            = azurerm.connectivity
  name                = "pip-${var.prefix}-afw-${var.location}-01"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  provider            = azurerm.connectivity
  name                = "afw-${var.prefix}-hub-${var.location}-01"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Centralized Private DNS Zone for Key Vault (linked to Hub)
resource "azurerm_private_dns_zone" "keyvault" {
  provider            = azurerm.connectivity
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.connectivity.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_hub" {
  provider              = azurerm.connectivity
  name                  = "link-kv-to-hub"
  resource_group_name   = azurerm_resource_group.connectivity.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}