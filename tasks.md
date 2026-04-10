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

## Phase 5: Enterprise Data & Governance

- [ ] Enable RAG API with Databricks embeddings
- [ ] Configure inference table logging
- [ ] Add OpenTelemetry instrumentation
- [ ] Set up audit and cost tracking

## Phase 6: Hardening

- [ ] Azure AD role gating (OPENID_REQUIRED_ROLE)
- [ ] Domain allowlisting
- [ ] Redis for sessions/cache
- [ ] Auto-scaling rules
- [ ] E2E smoke tests for Azure AD + Databricks

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
