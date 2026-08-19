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
# This script is idempotent — safe to re-run. Each create command tolerates
# "already exists" so partial runs can be resumed.

set -uo pipefail

# Prevent Git Bash (MSYS) from mangling /subscriptions/... paths into C:/Program Files/Git/...
export MSYS_NO_PATHCONV=1

# Set to "true" to enable VNet + private endpoints + role assignments
# Requires Owner or User Access Administrator role on the subscription
ENABLE_NETWORKING="false"           # true | false

#=============================================================================
# CONFIGURATION — Customize these before running
#=============================================================================

# Naming convention: <prefix>-<service>-<env>
PREFIX="ges-ai"
ENV="dev"                           # prod | dev | staging
LOCATION="westeurope"               # Azure region
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
DOCKER_IMAGE_NAME="enterprise-ai:latest"
DOCKER_IMAGE="${ACR_NAME}.azurecr.io/${DOCKER_IMAGE_NAME}"

# Networking
VNET_NAME="${PREFIX}-vnet-${ENV}"
SUBNET_APP="snet-app"              # App Service integration subnet
SUBNET_PE="snet-privateendpoints"  # Private endpoint subnet
VNET_CIDR="10.0.0.0/16"
SUBNET_APP_CIDR="10.0.1.0/24"
SUBNET_PE_CIDR="10.0.2.0/24"

# Custom domain (optional — leave empty to skip)
CUSTOM_DOMAIN=""                    # e.g., chat.yourcompany.com

echo "=========================================="
echo " Enterprise AI Platform — Azure Deployment"
echo "=========================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location:       ${LOCATION}"
echo "Environment:    ${ENV}"
echo ""

# Helper: run az command, tolerate "already exists" errors
az_create() {
  local step="$1"; shift
  if ! output=$("$@" 2>&1); then
    if echo "$output" | grep -qi "already exists\|conflict\|AlreadyExists"; then
      echo "  [${step}] Already exists — skipping."
    else
      echo "  [${step}] ERROR: $output" >&2
      return 1
    fi
  fi
}

#=============================================================================
# 1. Resource Group
#=============================================================================
echo "[1/16] Creating Resource Group..."
az_create "RG" az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --only-show-errors

#=============================================================================
# 2. Key Vault
#=============================================================================
echo "[2/16] Creating Key Vault..."
az_create "KV" az keyvault create \
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
echo "[3/16] Creating Cosmos DB (MongoDB API)..."
az_create "Cosmos" az cosmosdb create \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --kind MongoDB \
  --server-version 6.0 \
  --default-consistency-level Session \
  --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=false \
  --only-show-errors

az_create "CosmosDB" az cosmosdb mongodb database create \
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
echo "[4/16] Creating Azure Cache for Redis..."
az_create "Redis" az redis create \
  --name "$REDIS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku "$REDIS_SKU" \
  --vm-size "$REDIS_SIZE" \
  --minimum-tls-version "1.2" \
  --only-show-errors

# Redis takes several minutes to provision — get connection info later
echo "  Redis provisioning (may take 10-20 minutes)..."

#=============================================================================
# 5. Blob Storage
#=============================================================================
echo "[5/16] Creating Blob Storage..."
az_create "Storage" az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --only-show-errors

az_create "Container" az storage container create \
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
echo "[6/16] Creating Container Registry..."
az_create "ACR" az acr create \
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
echo "[7/16] Creating App Service Plan..."
az_create "Plan" az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP" \
  --sku "$APP_SERVICE_SKU" \
  --is-linux \
  --only-show-errors

#=============================================================================
# 8. Web App (Linux Container)
#=============================================================================
echo "[8/16] Creating Web App..."
ACR_SERVER="${ACR_NAME}.azurecr.io"
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

az_create "WebApp" az webapp create \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$APP_SERVICE_PLAN" \
  --container-image-name "$DOCKER_IMAGE_NAME" \
  --container-registry-url "https://${ACR_SERVER}" \
  --container-registry-user "$ACR_USER" \
  --container-registry-password "$ACR_PASS" \
  --only-show-errors

#=============================================================================
# 9. Managed Identity + Key Vault Access
#=============================================================================
echo "[9/16] Configuring Managed Identity..."
az webapp identity assign \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --only-show-errors 2>&1 | grep -v "^$" || true

PRINCIPAL_ID=$(az webapp identity show \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)

KEYVAULT_ID=$(az keyvault show \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

if [ "$ENABLE_NETWORKING" = "true" ]; then
  az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "Key Vault Secrets User" \
    --scope "$KEYVAULT_ID" \
    --only-show-errors 2>&1 | grep -v "^$" || true
  echo "  App Service can read Key Vault secrets."
else
  echo "  Skipping KV role assignment (ENABLE_NETWORKING=false)."
  echo "  MANUAL: Ask Azure admin to grant 'Key Vault Secrets User' to principal $PRINCIPAL_ID on $KEYVAULT_NAME"
  echo "  Or use Key Vault access policies instead of RBAC."
fi

#=============================================================================
# 10. App Settings
#=============================================================================
echo "[10/16] Configuring App Settings..."

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
    "CREDS_KEY=${CREDS_KEY:-@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/CREDS-KEY)}" \
    "CREDS_IV=${CREDS_IV:-@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/CREDS-IV)}" \
    "JWT_SECRET=${JWT_SECRET:-@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/JWT-SECRET)}" \
    "JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET:-@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/JWT-REFRESH-SECRET)}" \
    "DATABRICKS_API_KEY=${DATABRICKS_API_KEY:-@Microsoft.KeyVault(SecretUri=${KEYVAULT_URI}/secrets/DATABRICKS-API-KEY)}" \
    "AZURE_STORAGE_CONNECTION_STRING=${STORAGE_CONN}" \
    "AZURE_STORAGE_CONTAINER_NAME=${STORAGE_CONTAINER}" \
    "DOMAIN_CLIENT=https://${APP_SERVICE_NAME}.azurewebsites.net" \
    "DOMAIN_SERVER=https://${APP_SERVICE_NAME}.azurewebsites.net" \
  --only-show-errors

echo "  App settings configured with Key Vault references."
echo ""
echo "  MANUAL: Set these in Azure Portal or via 'az webapp config appsettings set':"
echo "    DATABRICKS_GATEWAY_URL=https://<workspace-id>.<region>.ai-gateway.azuredatabricks.net/mlflow/v1"
echo ""
echo "  OPTIONAL (Azure AD SSO — skip for local-auth-only testing):"
echo "    OPENID_CLIENT_ID=<app-registration-client-id>"
echo "    OPENID_CLIENT_SECRET=<app-registration-secret> (or Key Vault ref)"
echo "    OPENID_ISSUER=https://login.microsoftonline.com/<tenant-id>/v2.0"
echo "    OPENID_SESSION_SECRET=<openssl rand -hex 32>"
echo ""

#=============================================================================
# 11. Health Check + WebSockets
#=============================================================================
echo "[11/16] Configuring Health Check + WebSockets..."
az webapp config set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --generic-configurations '{"healthCheckPath": "/health"}' \
  --web-sockets-enabled true \
  --only-show-errors

#=============================================================================
# 12. VNet + Subnets
#=============================================================================
if [ "$ENABLE_NETWORKING" = "true" ]; then
echo "[12/16] Creating VNet and Subnets..."
az_create "VNet" az network vnet create \
  --name "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --address-prefixes "$VNET_CIDR" \
  --only-show-errors

az_create "SubnetApp" az network vnet subnet create \
  --name "$SUBNET_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --address-prefixes "$SUBNET_APP_CIDR" \
  --delegations "Microsoft.Web/serverFarms" \
  --only-show-errors

az_create "SubnetPE" az network vnet subnet create \
  --name "$SUBNET_PE" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --address-prefixes "$SUBNET_PE_CIDR" \
  --only-show-errors

# Disable network policies on PE subnet for private endpoints
az network vnet subnet update \
  --name "$SUBNET_PE" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --private-endpoint-network-policies Disabled \
  --only-show-errors 2>&1 | grep -v "^$" || true

#=============================================================================
# 13. App Service VNet Integration
#=============================================================================
echo "[13/16] Integrating App Service with VNet..."
az webapp vnet-integration add \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet "$VNET_NAME" \
  --subnet "$SUBNET_APP" \
  --only-show-errors 2>&1 | grep -v "^$" || true
echo "  App Service outbound traffic routes through VNet."

#=============================================================================
# 14. Private Endpoints (Cosmos DB, Redis, Key Vault, Storage)
#=============================================================================
echo "[14/16] Creating Private Endpoints..."

# Private DNS zones for each service
declare -A DNS_ZONES=(
  ["cosmos"]="privatelink.mongo.cosmos.azure.com"
  ["redis"]="privatelink.redis.cache.windows.net"
  ["keyvault"]="privatelink.vaultcore.azure.net"
  ["blob"]="privatelink.blob.core.windows.net"
)

for svc in cosmos redis keyvault blob; do
  az_create "DNS-${svc}" az network private-dns zone create \
    --name "${DNS_ZONES[$svc]}" \
    --resource-group "$RESOURCE_GROUP" \
    --only-show-errors

  az_create "DNSLink-${svc}" az network private-dns link vnet create \
    --name "${svc}-dns-link" \
    --resource-group "$RESOURCE_GROUP" \
    --zone-name "${DNS_ZONES[$svc]}" \
    --virtual-network "$VNET_NAME" \
    --registration-enabled false \
    --only-show-errors
done

# Cosmos DB private endpoint
COSMOS_ID=$(az cosmosdb show --name "$COSMOS_ACCOUNT" -g "$RESOURCE_GROUP" --query id -o tsv)
az_create "PE-Cosmos" az network private-endpoint create \
  --name "pe-${COSMOS_ACCOUNT}" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_PE" \
  --private-connection-resource-id "$COSMOS_ID" \
  --group-id "MongoDB" \
  --connection-name "cosmos-pe-conn" \
  --only-show-errors

az_create "PEDns-Cosmos" az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${COSMOS_ACCOUNT}" \
  --resource-group "$RESOURCE_GROUP" \
  --name "cosmos-dns-group" \
  --private-dns-zone "${DNS_ZONES[cosmos]}" \
  --zone-name "cosmos" \
  --only-show-errors

# Redis private endpoint
REDIS_ID=$(az redis show --name "$REDIS_NAME" -g "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null || echo "")
if [ -n "$REDIS_ID" ]; then
  az_create "PE-Redis" az network private-endpoint create \
    --name "pe-${REDIS_NAME}" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_PE" \
    --private-connection-resource-id "$REDIS_ID" \
    --group-id "redisCache" \
    --connection-name "redis-pe-conn" \
    --only-show-errors

  az_create "PEDns-Redis" az network private-endpoint dns-zone-group create \
    --endpoint-name "pe-${REDIS_NAME}" \
    --resource-group "$RESOURCE_GROUP" \
    --name "redis-dns-group" \
    --private-dns-zone "${DNS_ZONES[redis]}" \
    --zone-name "redis" \
    --only-show-errors
else
  echo "  Redis not ready — create PE manually after provisioning completes."
fi

# Key Vault private endpoint
az_create "PE-KV" az network private-endpoint create \
  --name "pe-${KEYVAULT_NAME}" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_PE" \
  --private-connection-resource-id "$KEYVAULT_ID" \
  --group-id "vault" \
  --connection-name "kv-pe-conn" \
  --only-show-errors

az_create "PEDns-KV" az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${KEYVAULT_NAME}" \
  --resource-group "$RESOURCE_GROUP" \
  --name "kv-dns-group" \
  --private-dns-zone "${DNS_ZONES[keyvault]}" \
  --zone-name "keyvault" \
  --only-show-errors

# Storage private endpoint
STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" -g "$RESOURCE_GROUP" --query id -o tsv)
az_create "PE-Blob" az network private-endpoint create \
  --name "pe-${STORAGE_ACCOUNT}" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_PE" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id "blob" \
  --connection-name "blob-pe-conn" \
  --only-show-errors

az_create "PEDns-Blob" az network private-endpoint dns-zone-group create \
  --endpoint-name "pe-${STORAGE_ACCOUNT}" \
  --resource-group "$RESOURCE_GROUP" \
  --name "blob-dns-group" \
  --private-dns-zone "${DNS_ZONES[blob]}" \
  --zone-name "blob" \
  --only-show-errors

echo "  Private endpoints created. Backend traffic stays in VNet."

#=============================================================================
# 15. ACR Managed Identity Pull (replace admin credentials)
#=============================================================================
echo "[15/16] Configuring ACR Managed Identity Pull..."
ACR_ID=$(az acr show --name "$ACR_NAME" -g "$RESOURCE_GROUP" --query id -o tsv)

az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "AcrPull" \
  --scope "$ACR_ID" \
  --only-show-errors 2>&1 | grep -v "^$" || true

az webapp config set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --generic-configurations '{"acrUseManagedIdentityCreds": true}' \
  --only-show-errors 2>&1 | grep -v "^$" || true
echo "  ACR pulls via Managed Identity (admin creds no longer needed)."

else
  echo "[12-15/16] Skipping VNet, private endpoints, role assignments (ENABLE_NETWORKING=false)."
  echo "  App uses public endpoints. Set ENABLE_NETWORKING=true when you have Owner/UAA role."
fi

#=============================================================================
# 16. Custom Domain + TLS (optional)
#=============================================================================
if [ -n "$CUSTOM_DOMAIN" ]; then
  echo "[16/16] Configuring Custom Domain: ${CUSTOM_DOMAIN}..."
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
  echo "[16/16] Skipping custom domain (CUSTOM_DOMAIN not set)."
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
echo "  3. Set remaining app settings (DATABRICKS_GATEWAY_URL)"
echo "  4. Create admin user: az webapp ssh --name $APP_SERVICE_NAME -g $RESOURCE_GROUP"
echo "     Then: cd /app && node config/create-user.js"
echo "  5. Restart app: az webapp restart --name $APP_SERVICE_NAME -g $RESOURCE_GROUP"
echo "  6. Verify: curl https://${APP_SERVICE_NAME}.azurewebsites.net/health"
echo ""
