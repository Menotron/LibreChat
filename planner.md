# Planner

Central planning document for tracking decisions, learnings, and implementation strategy.

## Project Identity

**Enterprise AI Platform** — a governed, branded alternative to ChatGPT/Claude desktop for business users. Built as a maintained fork of LibreChat, routing all inference through Databricks AI Gateway. Not a throwaway PoC — this is the organization's primary AI interaction surface.

**Core principles:**
- **Best-in-class UX** — match or exceed ChatGPT/Claude desktop experience
- **Enterprise-grade** — maintainable, scalable, secure, auditable code
- **Upstream-aligned** — stay mergeable with LibreChat to inherit its rapid innovation (new models, agent capabilities, MCP, streaming, bug fixes)
- **Config over code** — disable features via config rather than deleting code, minimizing merge friction

## Upstream Sync Strategy

LibreChat evolves rapidly. We ride that wave rather than diverge from it.

- **Upstream**: `danny-avila/LibreChat` `main` branch (currently based on v0.8.4)
- **Our branch**: `enterprise/phase4-pruning`
- **Sync trigger**: Security patches, new model support, agent/MCP improvements, streaming/perf fixes, features aligned with our roadmap
- **Process**: Fetch upstream -> merge on throwaway branch -> resolve conflicts -> build + test -> fast-forward enterprise branch
- **Conflict-prone files**: `api/strategies/`, `api/server/index.js`, `package.json`, deleted files (Assistants API, social logins)
- **Safe files (we own)**: `librechat.yaml`, `.env.enterprise`, `Dockerfile.enterprise`, `scripts/`, `docker-compose.azure.yml`, `.claude/`

## Current Phase

Phases 1, 2, and 4 complete. Phase 3 infrastructure scripts ready. Codespace smoke test complete — all 14 models confirmed working through Databricks AI Gateway. ENDPOINTS=custom (agents hidden until pre-built agents are ready). Next: Azure resource provisioning (Phase 3 execution), Phase 5 (RAG + governance), Phase 6 (hardening).

## Decisions Log

| Date | Decision | Rationale | Status |
|------|----------|-----------|--------|
| 2026-04-10 | Set up .claude scaffolding | Standardize agent routing, memory, and task tracking | Done |
| 2026-04-10 | Databricks AI Gateway via custom endpoint | OpenAI-compatible baseURL, zero code changes | Done |
| 2026-04-10 | ENDPOINTS=custom (was agents,custom) | Agents hidden — empty "My Agents" panel confuses users. Re-add when agents are pre-built | Done |
| 2026-04-10 | Moderate pruning level | Remove social logins + Assistants API, keep provider code config-disabled | Done |
| 2026-04-10 | Azure App Service over AKS | Simpler PaaS, can migrate later | Planned |
| 2026-04-10 | Hardcode model list in librechat.yaml | Databricks gateway doesn't support /v1/models | Done |
| 2026-04-10 | Use Codespaces for testing | Local Windows build blocked by corporate proxy | Done |
| 2026-04-10 | Delete .fly/ directory | Fly.io config irrelevant for Azure deployment | Done |
| 2026-04-10 | Keep .husky/, .turbo/, e2e/ | Quality gates, build perf, and testing still needed | Done |
| 2026-04-10 | Placeholder branding (Phase 2) | Text-based "Enterprise AI" logo, blue brand color, real assets later | Done |
| 2026-04-10 | Direct CSS edit over REACT_APP_THEME_* | REACT_APP_THEME_* requires Vite envPrefix + Docker ARGs; CSS edit is simpler | Done |
| 2026-04-10 | Dockerfile.enterprise based on Dockerfile.multi | Adds HEALTHCHECK, OCI labels, baked librechat.yaml | Done |
| 2026-04-10 | Azure deploy script (not Bicep/Terraform) | Simple az CLI for initial provisioning, IaC later if needed | Done |

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
| 2026-04-10 | dropParams fix: stripping user/stop/frequencyPenalty/etc. from request body fixes Anthropic 400 | Codespace testing | dropParams must be camelCase |
| 2026-04-10 | All 14 models confirmed working: opus-4-6/4-5/4-1, sonnet-4-6/4-5/4, haiku-4-5, 3-7-sonnet, gpt-oss-120b/20b, llama-4-maverick, llama-3-3-70b, llama-3-1-8b, gemma-3-12b | Codespace testing | Full model coverage |
| 2026-04-10 | Multi-turn + model switching mid-conversation works | Codespace testing | Core UX validated |

## Open Questions

- How to handle model list maintenance in production? (Options: hardcode in YAML, or build /v1/models proxy)
- Azure AD group-based access control config (OPENID_REQUIRED_ROLE) — needs testing with real Entra ID
- RAG API embedding model — can Databricks serve embeddings for LibreChat RAG?
- Upstream sync cadence — what's the right rhythm? Per-release, monthly, or triggered by specific features?
- Feature parity tracking — how do we systematically identify upstream features worth adopting?

## Phase Plan

### Phase 1: Config Foundation [COMPLETE]
- librechat.yaml with Databricks endpoint, addParams, dropParams
- .env.enterprise template
- ENDPOINTS=custom (agents hidden for cleaner UX)
- Debug logging (config.ts, run.ts) gated by DEBUG_LOGGING env var

### Phase 2: Custom Branding [COMPLETE]
- [x] Placeholder databricks.svg icon
- [x] Replaced logo.svg with text-based "Enterprise AI" placeholder
- [x] Brand color: --brand-purple changed to #2563eb (blue-600)
- [x] PWA manifest name updated to "Enterprise AI"
- [x] CUSTOM_FOOTER uncommented in .env.enterprise
- [x] Welcome message includes {{user.name}} template
- [ ] Real brand assets (deferred — placeholder is sufficient)

### Phase 3: Azure App Service Deployment [SCRIPTS READY]
- [x] Dockerfile.enterprise (based on Dockerfile.multi + HEALTHCHECK + OCI labels)
- [x] scripts/azure-deploy.sh (full az CLI provisioning: RG, KV, Cosmos, Redis, Blob, ACR, App Service, IAM)
- [x] docker-compose.azure.yml (local production-like testing)
- [x] .env.enterprise updated with Azure Blob Storage config
- [ ] Actual Azure resource provisioning (requires Azure subscription + credentials)
- [ ] Docker image build and push to ACR
- [ ] App Service configuration + first deploy

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

### Ongoing: Upstream Sync [RECURRING]
- Monitor LibreChat releases for security patches, bug fixes, new features
- Evaluate new agent/MCP capabilities for enterprise adoption
- Merge upstream changes on validated throwaway branch before fast-forwarding
- Track conflict resolution patterns to minimize future friction
- Document any upstream feature we intentionally skip and why
