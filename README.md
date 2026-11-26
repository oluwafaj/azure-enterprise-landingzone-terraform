# Azure Enterprise Landing Zone & Workload Terraform Project

This repository implements an enterprise-grade **Azure Landing Zone (ALZ)** architecture split into two decoupled layers with independent state files and CI/CD pipelines:

1. **`01-platform-landing-zone/`**: Manages Management Groups, Azure Policy guardrails, Central Log Analytics, and Hub Virtual Networking (Azure Firewall, Bastion, Private DNS Zones) using **Azure Verified Modules (AVM)**.
2. **`02-workload-landing-zone/`**: Deploys an isolated Workload Spoke VNet peered to the Hub, routing/NSG controls, Managed Identity, Key Vault, and application hosting with Private Endpoints.

## Prerequisites
- Terraform `>= 1.9.0`
- Azure CLI (`az`) `>= 2.60.0`
- An Azure Tenant with permissions to create Management Groups, Subscriptions, and Entra ID App Registrations.
