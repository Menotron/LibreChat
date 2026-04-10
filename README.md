# Enterprise AI Platform

A governed, enterprise-grade alternative to ChatGPT and Claude desktop — built as a **maintained fork** of [LibreChat](https://github.com/danny-avila/LibreChat). Provides a unified chat interface with agentic capabilities (MCP, code execution, RAG, custom agents), routed exclusively through **Databricks AI Gateway** for governance, inference tables, and cost tracking. Authenticated via Azure AD SSO.

We stay aligned with upstream LibreChat to inherit its rapid innovation (new models, streaming, agent framework) while adding enterprise controls, branding, and infrastructure.

## Architecture

```
Browser → Azure App Service (Docker) → LibreChat → Databricks AI Gateway → LLMs
                                          ↓
                                     MongoDB (Cosmos DB)
```

**Endpoints:** `custom` (Databricks) only. Agents endpoint available but hidden until pre-built agents are ready. All other providers config-disabled.

**Auth:** Azure AD / Entra ID (OpenID Connect) + local admin fallback.

## Quick Start (Codespaces)

1. Open Codespace on `enterprise/phase4-pruning` branch
2. `cp .env.enterprise .env` and fill in values:

| Variable | Generate with |
|---|---|
| `DATABRICKS_API_KEY` | Databricks PAT (scope: `serving.serving-endpoints-query`) |
| `DATABRICKS_GATEWAY_URL` | `https://<workspace-id>.<region>.ai-gateway.azuredatabricks.net/mlflow/v1` |
| `CREDS_KEY` | `openssl rand -hex 32` |
| `CREDS_IV` | `openssl rand -hex 16` |
| `JWT_SECRET` | `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET` | `openssl rand -hex 32` |

3. `npm ci && npm run build`
4. `npm run create-user` (create admin account)
5. `npm run backend`
6. Set port 3080 to **Public** in Ports tab

## Configuration

- **`librechat.yaml`** — Endpoint config, model list, interface settings, agent capabilities
- **`.env.enterprise`** — Template with all enterprise env vars documented
- **`.env`** — Runtime config (copy from `.env.enterprise`)

### Model List

Models are hardcoded in `librechat.yaml` to match Databricks serving endpoint names. To update:

```bash
# List available models from gateway
curl -s -H "Authorization: Bearer $DATABRICKS_API_KEY" \
  "https://<workspace>.azuredatabricks.net/api/2.0/serving-endpoints" \
  | jq -r '.endpoints[].name'
```

Update `librechat.yaml` → `endpoints.custom[0].models.default` with actual names.

## Key Features

- **AI Gateway Models** — Claude, GPT, Llama, Gemma via Databricks governance
- **Agents** — No-code custom assistants with MCP, code execution, file search, actions
- **Code Interpreter** — Sandboxed execution (Python, Node.js, Go, Rust, etc.)
- **RAG** — File upload + vector search (requires RAG API sidecar)
- **Resumable Streams** — Auto-reconnect on connection drops, multi-tab sync
- **RBAC** — Role-based access control with Azure AD group mapping

## Enterprise Modifications

Changes from upstream LibreChat:

| Change | Reason |
|---|---|
| Removed social logins (Discord, Facebook, GitHub, Google, Apple) | Only Azure AD SSO needed |
| Removed OpenAI Assistants API | Using LibreChat Agents with Databricks instead |
| Removed Fly.io config | Deploying on Azure App Service |
| Added Databricks AI Gateway endpoint | Sole LLM provider |
| Updated .devcontainer for Codespaces | Node 20 + enterprise env wiring |
| Placeholder branding (logo, brand color, PWA name) | Enterprise visual identity |
| Enterprise Dockerfile with HEALTHCHECK | Azure App Service health monitoring |

Provider endpoint code kept config-disabled (`ENDPOINTS=custom`) for upstream merge compatibility.

## Deployment

**Target:** Azure App Service (Docker)

### Quick Deploy

```bash
# 1. Provision Azure infrastructure
bash scripts/azure-deploy.sh

# 2. Build and push Docker image
az acr build --registry <acr-name> --image enterprise-ai:latest --file Dockerfile.enterprise .

# 3. Set remaining app settings (DATABRICKS_GATEWAY_URL, OPENID_*, DOMAIN_*)
# 4. Create admin user via App Service SSH
# 5. Restart: az webapp restart --name <app-name> -g <resource-group>
```

### Local Testing (Docker)

```bash
cp .env.enterprise .env
# Fill in DATABRICKS_API_KEY, DATABRICKS_GATEWAY_URL, secrets
docker compose -f docker-compose.azure.yml up --build
```

### Azure Resources

| Service | Azure Resource |
|---|---|
| App | App Service (Web App for Containers) |
| Database | Cosmos DB for MongoDB API |
| Cache | Azure Cache for Redis |
| Files | Azure Blob Storage |
| Vector DB | PostgreSQL Flexible Server + pgvector |
| Secrets | Azure Key Vault |
| Registry | Azure Container Registry |

See `helm/` for Kubernetes deployment if migrating to AKS later.

## Development

```bash
npm run backend:dev    # Backend with file watching
npm run frontend:dev   # Frontend dev server (port 3090)
npm run build          # Full build via Turborepo
npm run lint           # ESLint across all workspaces
```

## Upstream Sync

**Maintained fork** of [LibreChat v0.8.4](https://github.com/danny-avila/LibreChat). Branch `enterprise/phase4-pruning` tracks enterprise-specific changes.

We intentionally stay close to upstream to inherit bug fixes, new model support, agent/MCP improvements, and streaming enhancements. Enterprise customizations are isolated in config files and new files where possible.

```bash
# Sync upstream
git remote add upstream https://github.com/danny-avila/LibreChat.git  # one-time
git fetch upstream
git checkout -b merge/upstream-YYYY-MM-DD  # throwaway branch
git merge upstream/main
# Resolve conflicts (concentrated in api/strategies/, deleted files, package.json)
npm run build && npm run lint  # validate
# If clean: fast-forward enterprise branch
```

**Conflict zones**: `api/strategies/` (social logins removed), deleted Assistants API files, `package.json`.
**Safe zone (we own)**: `librechat.yaml`, `.env.enterprise`, `Dockerfile.enterprise`, `scripts/`, `.claude/`.
