output "corp_landing_zone_mg_id" {
  description = "Management Group ID where Corp workload subscriptions should be placed."
  value       = azurerm_management_group.lz_corp.id
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics Workspace resource ID."
  value       = azurerm_log_analytics_workspace.central.id
}

output "hub_vnet_id" {
  description = "Resource ID of the central Hub Virtual Network."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the central Hub Virtual Network."
  value       = azurerm_virtual_network.hub.name
}

output "hub_resource_group_name" {
  description = "Resource group containing the Hub VNet and Private DNS zones."
  value       = azurerm_resource_group.connectivity.name
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall for spoke UDR next-hop routing."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "keyvault_private_dns_zone_id" {
  description = "Resource ID of the centralized Key Vault Private DNS Zone."
  value       = azurerm_private_dns_zone.keyvault.id
}
