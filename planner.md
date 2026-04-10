# Planner

Central planning document for tracking decisions, learnings, and implementation strategy.

## Current Phase

Phase 4 complete. Debugging Anthropic model 400 errors — added debug logging (config.ts, run.ts) and dropParams for Databricks gateway. Next: test in Codespace, then Phase 2 branding, Phase 3 Azure App Service, Phase 5 RAG/governance.

## Decisions Log

| Date | Decision | Rationale | Status |
|------|----------|-----------|--------|
| 2026-04-10 | Set up .claude scaffolding | Standardize agent routing, memory, and task tracking | Done |
| 2026-04-10 | Databricks AI Gateway via custom endpoint | OpenAI-compatible baseURL, zero code changes | Done |
| 2026-04-10 | ENDPOINTS=agents,custom | Config-disable all other providers without code deletion | Done |
| 2026-04-10 | Moderate pruning level | Remove social logins + Assistants API, keep provider code config-disabled | Done |
| 2026-04-10 | Azure App Service over AKS | Simpler PaaS, can migrate later | Planned |
| 2026-04-10 | Hardcode model list in librechat.yaml | Databricks gateway doesn't support /v1/models | Done |
| 2026-04-10 | Use Codespaces for testing | Local Windows build blocked by corporate proxy | Done |
| 2026-04-10 | Delete .fly/ directory | Fly.io config irrelevant for Azure deployment | Done |
| 2026-04-10 | Keep .husky/, .turbo/, e2e/ | Quality gates, build perf, and testing still needed | Done |

## Learnings

| Date | Learning | Source | Impact |
|------|----------|--------|--------|
| 2026-04-10 | LibreChat monorepo: `/api` (JS) + `/packages/api` (TS) + `/client` (React) | Codebase exploration | Where new code goes |
| 2026-04-10 | Multi-tenant via AsyncLocalStorage + Mongoose scoping | Architecture analysis | DB-touching changes |
| 2026-04-10 | Resumable SSE streaming with pluggable JobStore/EventTransport | Stream module analysis | Real-time features |
| 2026-04-10 | ALLOW_SOCIAL_LOGIN=true required for OpenID to load | configureSocialLogins() wraps OpenID setup | Auth config |
| 2026-04-10 | Databricks gateway URL = workspace-id.region.ai-gateway.azuredatabricks.net/mlflow/v1 | Testing | baseURL for OpenAI SDK |
| 2026-04-10 | PAT needs `serving.serving-endpoints-query` scope | 403 error during testing | Databricks auth |
| 2026-04-10 | Model names must match Databricks serving endpoint names exactly | 404 MODEL_NOT_FOUND | Config accuracy |
| 2026-04-10 | Gateway /v1/models not supported — must hardcode model list | curl test | librechat.yaml config |
| 2026-04-10 | Codespace port forwarding must be Public to avoid 502 | Browser testing | Deployment gotcha |
| 2026-04-10 | controllers/assistants/helpers.js was imported by process.js and files.js | Build verification | Deeper pruning needed than plan anticipated |
| 2026-04-10 | auth.json ENOENT is Firebase/GCP — ignorable for enterprise | Server logs | Not a real error |
| 2026-04-10 | addParams max_tokens routes to modelKwargs (not llmConfig) — snake_case not in knownOpenAIParams | Code trace | Still functional — modelKwargs spread into body |
| 2026-04-10 | dropParams must use camelCase to match llmConfig keys (e.g., frequencyPenalty) | Code trace | Config accuracy |
| 2026-04-10 | initializeCustom always injects user:userId into modelOptions (line 170) | Code trace | Must drop 'user' if gateway rejects it |
| 2026-04-10 | Custom providers get streamUsage=false, usage=true in run.ts:348-354 | Code trace | No stream_options sent |
| 2026-04-10 | Custom endpoints override provider to Providers.OPENAI in providers.ts:85 | Code trace | Agents pipeline treats them as OpenAI |
| 2026-04-10 | All chat goes through agents pipeline (/api/agents/chat/completions) — no separate custom route | Code trace | Single code path to debug |

## Open Questions

- How to handle model list maintenance in production? (Options: hardcode in YAML, or build /v1/models proxy)
- Azure AD group-based access control config (OPENID_REQUIRED_ROLE) — needs testing with real Entra ID
- RAG API embedding model — can Databricks serve embeddings for LibreChat RAG?
- Anthropic 400 error root cause — debug logging added, dropParams configured; needs Codespace test to confirm fix

## Phase Plan

### Phase 1: Config Foundation [COMPLETE]
- librechat.yaml with Databricks endpoint
- .env.enterprise template
- ENDPOINTS=agents,custom

### Phase 2: Custom Branding [PARTIAL]
- [x] Placeholder databricks.svg icon
- [ ] Enterprise logo replacement
- [ ] Theme color overrides
- [ ] APP_TITLE and CUSTOM_FOOTER finalization

### Phase 3: Azure App Service Deployment [NOT STARTED]
- Docker image + ACR
- App Service config
- Cosmos DB / Redis / PostgreSQL (pgvector)
- Networking + custom domain

### Phase 4: Codebase Pruning [COMPLETE]
- [x] Remove social login strategies (Discord, Facebook, GitHub, Google, Apple)
- [x] Remove OpenAI Assistants API (routes, controllers, services, middleware)
- [x] Remove .fly/ directory
- [x] Update .devcontainer for Codespaces
- [x] Fix all affected imports, tests, and file operations

### Phase 5: Enterprise Data & Governance [NOT STARTED]
- RAG API setup
- Databricks inference tables
- OpenTelemetry
- Audit & cost tracking

### Phase 6: Hardening [NOT STARTED]
- Azure AD role gating
- Domain allowlisting
- Redis for sessions
- Auto-scaling
- Smoke tests
