#!/usr/bin/env bash
# azure-deploy.sh — Provision Azure infrastructure for Enterprise AI Platform
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Subscription selected (az account set -s <subscription-id>)
#
# Usage:
#   1. Review and customize the variables below
#   2. Run: bash scripts/azure-deploy.sh
#   3. After completion, populate Key Vault secrets manually
#   4. Push Docker image and restart App Service
#
# This script is idempotent — safe to re-run (uses --only-show-errors where possible)

set -euo pipefail

#=============================================================================
# CONFIGURATION — Customize these before running
#=============================================================================

# Naming convention: <prefix>-<service>-<env>
PREFIX="enterprise-ai"
ENV="prod"                          # prod | dev | staging
LOCATION="eastus"                   # Azure region
RESOURCE_GROUP="rg-${PREFIX}-${LOCATION}"

# Cosmos DB
COSMOS_ACCOUNT="${PREFIX}-cosmos-${ENV}"
COSMOS_DB_NAME="LibreChat"

# Redis
REDIS_NAME="${PREFIX}-redis-${ENV}"
REDIS_SKU="Basic"                   # Basic (dev) | Standard (prod)
REDIS_SIZE="C0"                     # C0 (250MB) | C1 (1GB) | C2 (2.5GB)

# Storage (Blob)
STORAGE_ACCOUNT="${PREFIX//-/}store${ENV}"  # alphanumeric only, 3-24 chars
STORAGE_CONTAINER="librechat-files"

# Key Vault
KEYVAULT_NAME="${PREFIX}-kv-${ENV}"

# Container Registry
ACR_NAME="${PREFIX//-/}acr${ENV}"   # alphanumeric only, 5-50 chars
ACR_SKU="Basic"                     # Basic | Standard | Premium

# App Service
APP_SERVICE_PLAN="${PREFIX}-plan-${ENV}"
APP_SERVICE_NAME="${PREFIX}-app-${ENV}"
APP_SERVICE_SKU="B1"                # B1 (dev) | P1v3 (prod)
DOCKER_IMAGE="${ACR_NAME}.azurecr.io/enterprise-ai:latest"

# Custom domain (optional — leave empty to skip)
CUSTOM_DOMAIN=""                    # e.g., chat.yourcompany.com

echo "=========================================="
echo " Enterprise AI Platform — Azure Deployment"
echo "=========================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location:       ${LOCATION}"
echo "Environment:    ${ENV}"
echo ""

#=============================================================================
# 1. Resource Group
#=============================================================================
echo "[1/12] Creating Resource Group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --only-show-errors

#=============================================================================
# 2. Key Vault
#=============================================================================
echo "[2/12] Creating Key Vault..."
az keyvault create \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku standard \
  --enable-rbac-authorization true \
  --only-show-errors

echo "  Populate secrets after deployment:"
echo "    az keyvault secret set --vault-name $KEYVAULT_NAME --name CREDS-KEY --value \$(openssl rand -hex 32)"
echo "    az keyvault secret set --vault-name $KEYVAULT_NAME --name CREDS-IV --value \$(openssl rand -hex 16)"
echo "    az keyvault secret set --vault-name $KEYVAULT_NAME --name JWT-SECRET --value \$(openssl rand -hex 32)"
echo "    az keyvault secret set --vault-name $KEYVAULT_NAME --name JWT-REFRESH-SECRET --value \$(openssl rand -hex 32)"
echo "    az keyvault secret set --vault-name $KEYVAULT_NAME --name DATABRICKS-API-KEY --value <your-pat>"
echo ""

#=============================================================================
# 3. Cosmos DB (MongoDB API)
#=============================================================================
echo "[3/12] Creating Cosmos DB (MongoDB API)..."
az cosmosdb create \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --kind MongoDB \
  --server-version 7.0 \
  --default-consistency-level Session \
  --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=false \
  --only-show-errors

az cosmosdb mongodb database create \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$COSMOS_DB_NAME" \
  --only-show-errors

COSMOS_CONN=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" -o tsv)
echo "  Cosmos DB connection string retrieved."

#=============================================================================
# 4. Azure Cache for Redis
#=============================================================================
echo "[4/12] Creating Azure Cache for Redis..."
az redis create \
  --name "$REDIS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku "$REDIS_SKU" \
  --vm-size "$REDIS_SIZE" \
  --enable-non-ssl-port false \
  --minimum-tls-version "1.2" \
  --only-show-errors

# Redis takes several minutes to provision — get connection info later
echo "  Redis provisioning (may take 10-20 minutes)..."

#=============================================================================
# 5. Blob Storage
#=============================================================================
echo "[5/12] Creating Blob Storage..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --only-show-errors

az storage container create \
  --name "$STORAGE_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --only-show-errors

STORAGE_CONN=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query connectionString -o tsv)
echo "  Storage connection string retrieved."

#=============================================================================
# 6. Azure Container Registry
#=============================================================================
echo "[6/12] Creating Container Registry..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku "$ACR_SKU" \
  --admin-enabled true \
  --only-show-errors

echo "  Build and push image:"
echo "    az acr build --registry $ACR_NAME --image enterprise-ai:latest --file Dockerfile.enterprise ."
echo ""

#=============================================================================
# 7. App Service Plan
#=============================================================================
echo "[7/12] Creating App Service Plan..."
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP" \
  --sku "$APP_SERVICE_SKU" \
  --is-linux \
  --only-show-errors

#=============================================================================
# 8. Web App (Linux Container)
#=============================================================================
echo "[8/12] Creating Web App..."
ACR_SERVER="${ACR_NAME}.azurecr.io"
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

az webapp create \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$APP_SERVICE_PLAN" \
  --container-image-name "$DOCKER_IMAGE" \
  --container-registry-url "https://${ACR_SERVER}" \
  --container-registry-user "$ACR_USER" \
  --container-registry-password "$ACR_PASS" \
  --only-show-errors

#=============================================================================
# 9. Managed Identity + Key Vault Access
#=============================================================================
echo "[9/12] Configuring Managed Identity..."
az webapp identity assign \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --only-show-errors

PRINCIPAL_ID=$(az webapp identity show \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)

KEYVAULT_ID=$(az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Key Vault Secrets User" \
  --scope "$KEYVAULT_ID" \
  --only-show-errors
echo "  App Service can read Key Vault secrets."

#=============================================================================
# 10. App Settings
#=============================================================================
echo "[10/12] Configuring App Settings..."

# Get Redis keys (may fail if still provisioning — retry manually)
REDIS_KEY=$(az redis list-keys \
  --name "$REDIS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query primaryKey -o tsv 2>/dev/null || echo "PENDING")

REDIS_HOST="${REDIS_NAME}.redis.cache.windows.net"
REDIS_URI="rediss://:${REDIS_KEY}@${REDIS_HOST}:6380"

KEYVAULT_URI="https://${KEYVAULT_NAME}.vault.azure.net"

az webapp config appsettings set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    WEBSITES_PORT=3080 \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    TRUST_PROXY=1 \
    NO_INDEX=true \
    CONSOLE_JSON=true \
    "MONGO_URI=${COSMOS_CONN}" \
    "REDIS_URI=${REDIS_URI}" \
    USE_REDIS=true \
    ENDPOINTS=custom \
    ALLOW_EMAIL_LOGIN=true \
    ALLOW_REGISTRATION=false \
    ALLOW_SOCIAL_LOGIN=true \
    ALLOW_SOCIAL_REGISTRATION=true \
    ALLOW_PASSWORD_RESET=false \
    ALLOW_UNVERIFIED_EMAIL_LOGIN=true \
    SEARCH=false \
    OPENAI_MODERATION=false \
    BAN_VIOLATIONS=true \
    "APP_TITLE=Enterprise AI" \
    "CUSTOM_FOOTER=Powered by Enterprise AI Platform" \
    ALLOW_SHARED_LINKS=true \
    ALLOW_SHARED_LINKS_PUBLIC=false \
    LIMIT_CONCURRENT_MESSAGES=true \
    CONCURRENT_MESSAGE_MAX=2 \
    "CREDS_KEY=@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/CREDS-KEY)" \
    "CREDS_IV=@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/CREDS-IV)" \
    "JWT_SECRET=@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/JWT-SECRET)" \
    "JWT_REFRESH_SECRET=@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/JWT-REFRESH-SECRET)" \
    "DATABRICKS_API_KEY=@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/DATABRICKS-API-KEY)" \
    "AZURE_STORAGE_CONNECTION_STRING=${STORAGE_CONN}" \
    "AZURE_STORAGE_CONTAINER_NAME=${STORAGE_CONTAINER}" \
  --only-show-errors

echo "  App settings configured with Key Vault references."
echo ""
echo "  MANUAL: Set these in Azure Portal or via 'az webapp config appsettings set':"
echo "    DATABRICKS_GATEWAY_URL=https://<workspace>.azuredatabricks.net/serving-endpoints/<gateway>/invocations/v1"
echo "    OPENID_CLIENT_ID=<app-registration-client-id>"
echo "    OPENID_CLIENT_SECRET=<app-registration-secret> (or Key Vault ref)"
echo "    OPENID_ISSUER=https://login.microsoftonline.com/<tenant-id>/v2.0"
echo "    OPENID_SESSION_SECRET=<openssl rand -hex 32>"
echo "    DOMAIN_CLIENT=https://${APP_SERVICE_NAME}.azurewebsites.net"
echo "    DOMAIN_SERVER=https://${APP_SERVICE_NAME}.azurewebsites.net"
echo ""

#=============================================================================
# 11. Health Check
#=============================================================================
echo "[11/12] Configuring Health Check..."
az webapp config set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --generic-configurations '{"healthCheckPath": "/health"}' \
  --only-show-errors

#=============================================================================
# 12. Custom Domain + TLS (optional)
#=============================================================================
if [ -n "$CUSTOM_DOMAIN" ]; then
  echo "[12/12] Configuring Custom Domain: ${CUSTOM_DOMAIN}..."
  az webapp config hostname add \
    --webapp-name "$APP_SERVICE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --hostname "$CUSTOM_DOMAIN" \
    --only-show-errors

  az webapp config ssl create \
    --name "$APP_SERVICE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --hostname "$CUSTOM_DOMAIN" \
    --only-show-errors

  echo "  Custom domain configured with managed TLS."
  echo "  CNAME: ${CUSTOM_DOMAIN} → ${APP_SERVICE_NAME}.azurewebsites.net"
else
  echo "[12/12] Skipping custom domain (CUSTOM_DOMAIN not set)."
  echo "  App URL: https://${APP_SERVICE_NAME}.azurewebsites.net"
fi

#=============================================================================
# Staging Slot (optional — uncomment for production)
#=============================================================================
# echo "Creating staging slot..."
# az webapp deployment slot create \
#   --name "$APP_SERVICE_NAME" \
#   --resource-group "$RESOURCE_GROUP" \
#   --slot staging \
#   --only-show-errors
#
# echo "  Deploy to staging:"
# echo "    az webapp config container set --name $APP_SERVICE_NAME -g $RESOURCE_GROUP --slot staging --container-image-name $DOCKER_IMAGE"
# echo "  Swap to production:"
# echo "    az webapp deployment slot swap --name $APP_SERVICE_NAME -g $RESOURCE_GROUP --slot staging --target-slot production"

echo ""
echo "=========================================="
echo " Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Populate Key Vault secrets (see step 2 output above)"
echo "  2. Build and push Docker image:"
echo "     az acr build --registry $ACR_NAME --image enterprise-ai:latest --file Dockerfile.enterprise ."
echo "  3. Set remaining app settings (DATABRICKS_GATEWAY_URL, OPENID_*, DOMAIN_*)"
echo "  4. Create admin user: az webapp ssh --name $APP_SERVICE_NAME -g $RESOURCE_GROUP"
echo "     Then: cd /app && node config/create-user.js"
echo "  5. Restart app: az webapp restart --name $APP_SERVICE_NAME -g $RESOURCE_GROUP"
echo "  6. Verify: curl https://${APP_SERVICE_NAME}.azurewebsites.net/health"
echo ""
