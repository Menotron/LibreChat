# Tasks

All todos and phased tasks for the current work stream.

## Legend

- [ ] Pending
- [x] Completed
- [~] In Progress
- [!] Blocked

---

## Setup

- [x] Create .claude directory structure
- [x] Create planner.md and tasks.md
- [x] Create agent routing guidelines
- [x] Create /review command
- [x] Create memory files
- [x] Create docs directory with architecture.md and prd.md

---

## Phase 1: Config Foundation [COMPLETE]

- [x] Create librechat.yaml with Databricks AI Gateway endpoint
- [x] Create .env.enterprise template
- [x] Configure ENDPOINTS (started agents+custom, now custom-only)
- [x] Update model list to match actual Databricks serving endpoints
- [x] Add dropParams for Databricks gateway compatibility
- [x] Add debug logging (config.ts, run.ts) gated by DEBUG_LOGGING

## Phase 2: Custom Branding [COMPLETE]

- [x] Add placeholder databricks.svg icon
- [x] Replace logo.svg with text-based "Enterprise AI" placeholder
- [x] Update brand color (--brand-purple: #ab68ff → #2563eb)
- [x] Update PWA manifest name to "Enterprise AI"
- [x] Uncomment CUSTOM_FOOTER in .env.enterprise
- [x] Add {{user.name}} to welcome message in librechat.yaml
- [ ] Replace with real brand assets when available

## Phase 3: Azure App Service Deployment [SCRIPTS READY]

- [x] Create Dockerfile.enterprise (multi-stage, HEALTHCHECK, OCI labels, baked config)
- [x] Create scripts/azure-deploy.sh (full az CLI provisioning)
- [x] Create docker-compose.azure.yml (local production-like testing)
- [x] Add Azure Blob Storage config to .env.enterprise
- [x] Update librechat.yaml fileStrategy comment
- [ ] Provision Azure resources (run azure-deploy.sh with real subscription)
- [ ] Build and push Docker image to ACR
- [ ] Configure remaining app settings (DATABRICKS_GATEWAY_URL, OPENID_*)
- [ ] Create admin user on App Service
- [ ] Set up custom domain + TLS
- [ ] Configure deployment slots (staging + production)

## Phase 4: Codebase Pruning [COMPLETE]

- [x] Remove social login strategies (Discord, Facebook, GitHub, Google, Apple)
- [x] Remove OpenAI Assistants API code (routes, controllers, services, middleware)
- [x] Remove .fly/ directory
- [x] Update .devcontainer for Node 20 + Codespaces
- [x] Fix all affected imports and test files
- [x] Verify syntax on all 14 modified files
- [x] Commit and push to enterprise/phase4-pruning branch

## Sprint 1: Demo-Ready — Config Only [BLOCKED: Azure deploy]

All config-only. No code changes. **Prerequisite: Phase 3 Azure deployment must complete first.**

- [ ] 1.1 Add modelSpecs with enforce:true, system prompts, per-model params (librechat.yaml)
- [ ] 1.2 Re-enable agents endpoint (ENDPOINTS=custom,agents), create pre-built agents
- [ ] 1.3 Configure MCP servers in librechat.yaml, lock user creation
- [ ] 1.4 Enable web search (Serper + Jina reranking)
- [ ] 1.5 Enable Redis (USE_REDIS=true, REDIS_URI)
- [ ] 1.6 Add governance headers (x-conversation-id, x-user-id) to Databricks endpoint
- [ ] 1.7 Enable artifacts on modelSpecs
- [ ] 1.8 Configure Azure AD role gating (OPENID_REQUIRED_ROLE, OPENID_ADMIN_ROLE)
- [ ] 1.9 Configure domain allowlisting (registration, MCP, actions)

## Sprint 2: Full Feature Stack — Config + Docker [BLOCKED: Sprint 1]

Requires additional Docker services.

- [ ] 2.1 RAG pipeline: add vectordb + rag_api to docker-compose, configure embedding model
- [ ] 2.2 Enable Meilisearch for conversation search
- [ ] 2.3 Configure token balance system (per-user usage tracking)
- [ ] 2.4 Enable code execution sandbox (hosted or self-hosted)
- [ ] 2.5 Add SearXNG self-hosted search (optional, replaces Serper)

## Sprint 3-4: Production-Ready — Code Changes [BLOCKED: Sprint 2]

New enterprise modules in isolated files.

- [ ] 3.1 Structured audit trail (MongoDB AuditLog collection)
- [ ] 3.2 OpenTelemetry instrumentation (auto + custom spans)
- [ ] 3.3 Enhanced health check endpoint (/api/health/detailed)
- [ ] 3.4 Content moderation middleware
- [ ] 3.5 Performance tuning (compression, DB pool, rate limits)
- [ ] 3.6 Azure Blob Storage for file uploads

## Sprint 5-6: Enterprise-Grade — Advanced [BLOCKED: Sprint 3-4]

- [ ] 4.1 Advanced guardrails engine (PII, prompt injection, topic blocklist)
- [ ] 4.2 OpenCode integration as MCP server
- [ ] 4.3 Custom visualization framework (Plotly, D3, Chart.js in artifacts)
- [ ] 4.4 Advanced multi-agent workflows (graph edges)
- [ ] 4.5 Compliance reporting dashboard

---

## Ongoing: Upstream Sync

- [ ] Add upstream remote: `git remote add upstream https://github.com/danny-avila/LibreChat.git`
- [ ] Review upstream releases for security patches and bug fixes
- [ ] Evaluate new agent/MCP features for enterprise adoption
- [ ] First upstream merge (from v0.8.4 baseline to latest)
- [ ] Document merge conflict resolution patterns

---

## Codespace Smoke Test [COMPLETE]

- [x] Push to GitHub (Menotron/LibreChat, branch enterprise/phase4-pruning)
- [x] Launch Codespace, npm ci + build
- [x] Create admin user, start backend
- [x] Login works (smenon@glanbia.net)
- [x] Fix 502 (set port to Public)
- [x] Fix 403 (PAT scope: serving.serving-endpoints-query)
- [x] Fix 404 (model names: databricks-claude-sonnet-4-6 etc.)
- [x] Verify chat completion works with GPT-oss models
- [x] Fix Anthropic model 400 errors (dropParams stripped OpenAI-only params)
- [x] Verify Anthropic models work (opus-4-5, haiku-4-5, sonnet-4-5, opus-4-1 all confirmed)
- [x] Verify multi-turn conversations work (model switching mid-convo confirmed)
- [x] Hide agents endpoint (ENDPOINTS=custom) for cleaner UX
