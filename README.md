# Enterprise AI Platform

Self-hosted AI chat platform powered by [LibreChat](https://github.com/danny-avila/LibreChat), configured exclusively for **Databricks AI Gateway** with Azure AD SSO.

All LLM inference routes through Databricks for governance, inference tables, and OpenTelemetry.

## Architecture

```
Browser → Azure App Service (Docker) → LibreChat → Databricks AI Gateway → LLMs
                                          ↓
                                     MongoDB (Cosmos DB)
```

**Endpoints:** `agents` + `custom` (Databricks) only. All other providers config-disabled.

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

Provider endpoint code kept config-disabled (`ENDPOINTS=agents,custom`) for upstream merge compatibility.

## Deployment

**Target:** Azure App Service (Docker)

See `helm/` for Kubernetes deployment if migrating to AKS later.

| Service | Azure Resource |
|---|---|
| App | App Service (Web App for Containers) |
| Database | Cosmos DB for MongoDB API |
| Cache | Azure Cache for Redis |
| Vector DB | PostgreSQL Flexible Server + pgvector |
| Secrets | Azure Key Vault |
| Registry | Azure Container Registry |

## Development

```bash
npm run backend:dev    # Backend with file watching
npm run frontend:dev   # Frontend dev server (port 3090)
npm run build          # Full build via Turborepo
npm run lint           # ESLint across all workspaces
```

## Upstream

Based on [LibreChat v0.8.4](https://github.com/danny-avila/LibreChat). Branch `enterprise/phase4-pruning` tracks enterprise-specific changes.

To sync upstream: merge `main` from `danny-avila/LibreChat`, resolve conflicts in modified files.
