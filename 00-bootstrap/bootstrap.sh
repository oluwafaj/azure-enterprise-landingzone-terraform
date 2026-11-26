#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Bootstrap Script: Creates Remote Terraform State Storage & OIDC App Registration
# Run this ONCE from a privileged Azure CLI session before running Terraform.
# ==============================================================================

LOCATION="uksouth"
MGMT_SUBSCRIPTION_ID="1adf80ff-67ea-4ac7-91eb-3a328416d9b7"
RESOURCE_GROUP_NAME="rg-tfstate-platform-prod-01"
STORAGE_ACCOUNT_NAME="sttfstatealz$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"
GITHUB_ORG="https://github.com/oluwafaj"
GITHUB_REPO="azure-enterprise-landingzone-terraform"

echo "Setting active subscription to Management subscription..."
az account set --subscription "$MGMT_SUBSCRIPTION_ID"

echo "Creating Resource Group: $RESOURCE_GROUP_NAME"
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"

echo "Creating Storage Account for Terraform State: $STORAGE_ACCOUNT_NAME"
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --sku Standard_GRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Enabling Blob Versioning and Soft Delete..."
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30

echo "Creating Blob Container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login

echo "Creating Entra ID App Registration for GitHub Actions OIDC..."
APP_ID=$(az ad app create --display-name "sp-terraform-alz-github" --query appId -o tsv)
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

echo "Configuring OIDC Federated Credential for 'main' branch..."
az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"github-main-branch\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
  \"description\": \"Deploy from main branch\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"

echo "=============================================================================="
echo "BOOTSTRAP COMPLETE!"
echo "Save these values for your backend.tf and GitHub Secrets:"
echo "  ARM_CLIENT_ID:       $APP_ID"
echo "  ARM_TENANT_ID:       $(az account show --query tenantId -o tsv)"
echo "  ARM_SUBSCRIPTION_ID: $MGMT_SUBSCRIPTION_ID"
echo "  TFSTATE_RG:          $RESOURCE_GROUP_NAME"
echo "  TFSTATE_STORAGE:     $STORAGE_ACCOUNT_NAME"
echo "  TFSTATE_CONTAINER:   $CONTAINER_NAME"
echo "=============================================================================="
