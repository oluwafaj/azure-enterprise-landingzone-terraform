variable "workload_name" {
  description = "Short name of the application workload."
  type        = string
  default     = "orders"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region matching the Hub VNet."
  type        = string
  default     = "uksouth"
}

variable "workload_subscription_id" {
  description = "Subscription ID hosting this workload."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Connectivity Subscription ID hosting the Hub VNet."
  type        = string
}

variable "spoke_vnet_address_space" {
  description = "Non-overlapping CIDR block for the workload Spoke VNet."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "app_subnet_prefix" {
  description = "Subnet CIDR for application compute."
  type        = string
  default     = "10.10.1.0/24"
}

variable "pe_subnet_prefix" {
  description = "Subnet CIDR for Private Endpoints."
  type        = string
  default     = "10.10.2.0/24"
}

variable "tfstate_resource_group_name" {
  description = "Resource group holding platform remote state."
  type        = string
  default     = "rg-tfstate-platform-prod-01"
}

variable "tfstate_storage_account_name" {
  description = "Storage account holding platform remote state."
  type        = string
}
