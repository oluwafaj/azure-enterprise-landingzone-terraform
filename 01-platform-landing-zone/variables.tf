variable "prefix" {
  description = "Organization prefix used across management groups and platform resources."
  type        = string
  default     = "contoso"
}

variable "location" {
  description = "Primary Azure region for platform management and hub networking."
  type        = string
  default     = "uksouth"
}

variable "root_parent_management_group_id" {
  description = "Tenant Root Group ID (usually your Entra Tenant ID)."
  type        = string
}

variable "management_subscription_id" {
  description = "Subscription ID dedicated to central logging and management."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Subscription ID dedicated to hub networking, firewall, and DNS."
  type        = string
}

variable "hub_vnet_address_space" {
  description = "CIDR block for the central Hub Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "firewall_subnet_prefix" {
  description = "CIDR block for AzureFirewallSubnet (minimum /26)."
  type        = string
  default     = "10.0.1.0/26"
}

variable "bastion_subnet_prefix" {
  description = "CIDR block for AzureBastionSubnet (minimum /26)."
  type        = string
  default     = "10.0.2.0/26"
}

variable "tags" {
  description = "Default governance tags applied to platform resources."
  type        = map(string)
  default = {
    Environment = "Platform"
    ManagedBy   = "Terraform"
    Owner       = "PlatformEngineering"
  }
}
