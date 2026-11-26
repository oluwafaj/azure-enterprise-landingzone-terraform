output "workload_resource_group_name" {
  value = azurerm_resource_group.workload.name
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "workload_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "key_vault_uri" {
  value = azurerm_key_vault.workload.vault_uri
}
