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

Phases 1 (config), 2 (branding), and 4 (pruning) complete. Phase 3 Azure infra scripts ready but not executed. Codespace smoke test complete — all 14 models confirmed working through Databricks AI Gateway. ENDPOINTS=custom (agents hidden until pre-built agents are ready).

**Next milestone:** Phase 3 execution (Azure resource provisioning), then Sprint 1 (config-only feature enablement). Full roadmap through Sprint 6 documented below. Sprint 1 is blocked on Azure deployment — no config changes until infrastructure is live.

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
| 2026-04-10 | App Service first, AKS later | Helm chart exists in helm/ for migration. App Service simpler for pilot (~$50-100/mo vs $300+). HPA templates ready | Confirmed |
| 2026-04-10 | Cosmos DB for MongoDB API v7.0 | 85% compatible. Fix: partial filter indexes (3 schemas), disable GridFS cache, add retryWrites=false | In Progress |
| 2026-04-10 | Doc generation via code sandbox | No native binary file output. Use code execution (python-pptx, python-docx, fpdf2) for PPTX/DOCX/PDF generation | Planned |
| 2026-04-10 | AionUi — concepts only, no code adoption | Different arch (Electron/SQLite/Bun). Worth stealing: scheduled tasks, OfficeCLI concept. Not worth porting code | Decided |
| 2026-04-10 | OpenCode — future MCP integration only | Code-focused CLI, no document handling. Keep as Sprint 5-6 MCP server wrapper | Confirmed |

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
| 2026-04-10 | LibreChat has built-in doc parsing: PDF (pdfjs-dist), DOCX (mammoth), XLSX (xlsx), ODT (yauzl) | Codebase exploration | No PPTX parser — needs Mistral OCR or RAG sidecar |
| 2026-04-10 | Multimodal fully wired: provider-specific image encoding (OpenAI, Anthropic, Google, Bedrock) | Codebase exploration | Image upload works out of the box |
| 2026-04-10 | OCR fallback chain: Mistral OCR → Document Parser → RAG API → native text | Codebase exploration | Multiple fallback layers for doc processing |
| 2026-04-10 | Artifacts are text-only output (code, HTML, markdown) — no binary file generation | Codebase exploration | PPTX/DOCX/PDF gen requires code execution sandbox |
| 2026-04-10 | Cosmos DB partial filter expressions NOT supported — 3 index defs in user.ts, file.ts, group.ts | Codebase + Cosmos docs | Must patch before deploy |
| 2026-04-10 | GridFSBucket in keyvMongo.ts not Cosmos-compatible — use Redis cache instead | Codebase + Cosmos docs | Redis already planned (Sprint 1.5) |
| 2026-04-10 | Transactions: LibreChat already has graceful fallback via supportsTransactions() | Codebase exploration | Cosmos DB transactions work if replica set enabled |
| 2026-04-10 | Helm chart in helm/librechat/ is production-ready (HPA, probes, Redis/Mongo/Meili bundled) | Codebase exploration | AKS migration path clear when needed |

## Open Questions

- How to handle model list maintenance in production? (Options: hardcode in YAML, or build /v1/models proxy)
- Azure AD group-based access control config (OPENID_REQUIRED_ROLE) — needs testing with real Entra ID
- RAG API embedding model — can Databricks serve embeddings for LibreChat RAG? Or use self-hosted embeddings?
- Upstream sync cadence — what's the right rhythm? Per-release, monthly, or triggered by specific features?
- Feature parity tracking — how do we systematically identify upstream features worth adopting?
- Code execution sandbox — use LibreChat hosted API or self-host Piston?
- Content moderation — route through Databricks or Azure Content Safety API?
- OpenCode integration approach — MCP server wrapper or deeper UI integration?
- SearXNG vs Serper for web search — cost vs data sovereignty tradeoff

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

### Sprint 1: Demo-Ready — Config Only [NOT STARTED]
All items are config-only — touch `librechat.yaml`, `.env.enterprise`, `docker-compose.azure.yml`. No code changes. **Prerequisite: Azure deployment (Phase 3 execution) must complete first.**

- **1.1 System Prompts via modelSpecs [P0]** — Add `modelSpecs` with `enforce: true` in `librechat.yaml`. Curated model list with org-wide system prompts (`promptPrefix`), default params, capability flags. Existing code: `packages/data-schemas/src/app/specs.ts`, `packages/api/src/agents/load.ts`
- **1.2 Re-enable Agents Endpoint [P0]** — Change `ENDPOINTS=custom` to `ENDPOINTS=custom,agents`. Create 2-3 pre-built agents via UI (Knowledge Agent, Code Agent, Data Analyst)
- **1.3 Configure MCP Servers [P0]** — Add `mcpServers:` section in `librechat.yaml` with enterprise data access servers (filesystem, fetch, database). Lock user creation: `interface.mcpServers.create: false`
- **1.4 Enable Web Search [P0]** — Add `webSearch:` section with Serper (Google API) + Jina reranking. Env vars: `SERPER_API_KEY`, `JINA_API_KEY`
- **1.5 Enable Redis [P0]** — Uncomment `USE_REDIS=true`, `REDIS_URI`. Already wired in `docker-compose.azure.yml`
- **1.6 Governance Headers [P1]** — Uncomment `headers:` block on Databricks endpoint — `x-conversation-id`, `x-user-id` for inference table correlation
- **1.7 Enable Artifacts [P1]** — Set `artifacts: true` on modelSpecs. No additional config needed. Rich output: Mermaid diagrams, HTML preview, charts
- **1.8 Azure AD Role Gating [P1]** — Set `OPENID_REQUIRED_ROLE`, `OPENID_ADMIN_ROLE` with Azure AD group IDs
- **1.9 Domain Allowlisting [P1]** — Uncomment `registration.allowedDomains`, `mcpSettings.allowedDomains`, `actions.allowedDomains`

### Sprint 2: Full Feature Stack — Config + Docker [NOT STARTED]
Requires additional Docker services (vectordb, rag_api, meilisearch).

- **2.1 RAG Pipeline [P0]** — Add `vectordb` (pgvector) and `rag_api` (librechat-rag-api) services to docker-compose. Configure `RAG_API_URL`, `EMBEDDINGS_PROVIDER`, `EMBEDDINGS_MODEL`. Decision needed: Can Databricks serve embeddings? Existing code: `packages/api/src/files/rag.ts`
- **2.2 Enable Meilisearch [P1]** — Add meilisearch service, set `SEARCH=true`, `MEILI_HOST`, `MEILI_MASTER_KEY`
- **2.3 Token Balance System [P1]** — Add `balance:` section (enabled, startBalance, autoRefill). Set `CHECK_BALANCE=true`. Existing code: `packages/data-schemas/src/schema/balance.ts`, `packages/api/src/agents/transactions.ts`
- **2.4 Code Execution Sandbox [P1]** — Set `LIBRECHAT_CODE_API_KEY` for hosted sandbox, OR deploy self-hosted (Piston). Existing code: `packages/api/src/tools/classification.ts` checks `EnvVar.CODE_API_KEY`
- **2.5 SearXNG Self-Hosted Search [P2]** — Add SearXNG container as alternative to Serper (no API key cost, queries don't leave network)

### Sprint 3-4: Production-Ready — Code Changes [NOT STARTED]
New enterprise modules — isolated in new files to minimize upstream merge friction.

- **3.1 Structured Audit Trail [P0, High]** — New: `packages/data-schemas/src/schema/auditLog.ts`, `packages/api/src/audit/service.ts`, `packages/api/src/middleware/audit.ts`. MongoDB `AuditLog` collection: login/logout, role changes, agent CRUD, MCP tool execution, config changes. Wire into auth strategies, admin routes, agent controllers
- **3.2 OpenTelemetry [P0, High]** — New: `packages/api/src/telemetry/init.ts`, `spans.ts`, `metrics.ts`. Auto-instrumentation (HTTP, Express, MongoDB, Redis) + custom spans for LLM calls, tool execution, MCP. Env: `OTEL_ENABLED`, `OTEL_EXPORTER_OTLP_ENDPOINT`. Export to Azure Monitor or Grafana
- **3.3 Enhanced Health Check [P1, Med]** — New: `packages/api/src/health/detailed.ts`. `/api/health/detailed` reporting per-component status (MongoDB, Redis, Meilisearch, RAG API, MCP servers)
- **3.4 Content Moderation [P1, Med]** — Option A: Route through Databricks moderation endpoint. Option B: New `packages/api/src/middleware/contentSafety.ts` for Azure Content Safety API
- **3.5 Performance Tuning [P1, Config]** — `ENABLE_COMPRESSION=true`, MongoDB pool tuning (`maxPoolSize=50`), rate limit tuning
- **3.6 Azure Blob Storage [P1, Config]** — Set `fileStrategy: "azure_blob"` in `librechat.yaml`. Existing code: `api/server/services/Files/Azure/`

### Sprint 5-6: Enterprise-Grade — Advanced Code [NOT STARTED]

- **4.1 Advanced Guardrails Engine [P2, High]** — New module: `packages/api/src/guardrails/`. Pluggable rules: PII detection, prompt injection, topic blocklist, output validation. Hook into agent pipeline pre/post LLM call
- **4.2 OpenCode Integration [P2, High]** — Wrap as MCP server: `packages/api/src/mcp/servers/opencode/`. Go CLI for terminal-like code gen/execution. MCP bridge launches sessions, pipes results. Future: dedicated UI panel
- **4.3 Custom Visualization Framework [P2, Med]** — Extend artifacts with chart renderers (Plotly, D3, Chart.js). New: `client/src/components/Artifacts/ChartRenderer.tsx`
- **4.4 Advanced Agent Workflows [P2, Med]** — Multi-agent pipelines using graph edges (Research → Summarize, Code → Review). Already supported: `packages/api/src/agents/edges.ts`, `MultiAgentGraphConfig`
- **4.5 Compliance Reporting [P2, Med]** — Admin dashboard: token usage by user/model, audit log search, session monitoring. Extend `api/server/routes/admin/`

### Dependency Map

```
Sprint 1 (config-only, all parallel after Azure deploy):
  1.1 modelSpecs → enables 1.7 Artifacts
  1.2 Agents, 1.3 MCP, 1.4 Web Search, 1.5 Redis — independent
  1.6 Governance Headers, 1.8 AD Roles, 1.9 Allowlists — independent

Sprint 2 (config + docker):
  2.1 RAG ← needs vectordb + rag_api containers
  2.2 Meilisearch ← needs container
  2.3 Token Balance, 2.4 Code Sandbox — independent

Sprint 3-4 (code):
  3.1 Audit Trail, 3.2 OpenTelemetry — independent
  3.3 Health Check, 3.5 Perf Tuning, 3.6 Azure Blob — independent

Sprint 5-6 (advanced):
  4.1 Guardrails → extends 1.1 modelSpecs
  4.2 OpenCode → extends 1.3 MCP
  4.3 Visualizations → extends 1.7 Artifacts
  4.4 Agent Workflows → extends 1.2 Agents
  4.5 Compliance → depends on 3.1 Audit + 2.3 Balance
```

### Demo-Ready Verification Checklist

After Sprint 1-2, the platform should demonstrate:
- [ ] Multi-model chat with enforced system prompts (modelSpecs)
- [ ] Pre-built agents with tool access (web search, file search, code execution)
- [ ] MCP server integration for enterprise data access
- [ ] Web search with reranking
- [ ] Document upload + RAG retrieval with citations
- [ ] Conversation search (Meilisearch)
- [ ] Artifact rendering (Mermaid diagrams, HTML, code preview)
- [ ] Token usage tracking per user
- [ ] Azure AD SSO with role-based access
- [ ] Redis-backed sessions with resumable streaming
- [ ] Governance headers to Databricks inference tables

### Ongoing: Upstream Sync [RECURRING]
- Monitor LibreChat releases for security patches, bug fixes, new features
- Evaluate new agent/MCP capabilities for enterprise adoption
- Merge upstream changes on validated throwaway branch before fast-forwarding
- Track conflict resolution patterns to minimize future friction
- Document any upstream feature we intentionally skip and why
