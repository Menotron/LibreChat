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

## Phase 1: Config Foundation

- [x] Create librechat.yaml with Databricks AI Gateway endpoint
- [x] Create .env.enterprise template
- [x] Configure ENDPOINTS=agents,custom
- [x] Update model list to match actual Databricks serving endpoints

## Phase 2: Custom Branding

- [x] Add placeholder databricks.svg icon
- [ ] Replace logo with enterprise branding
- [ ] Override theme CSS variables
- [ ] Finalize APP_TITLE, CUSTOM_FOOTER, welcome message

## Phase 3: Azure App Service Deployment

- [ ] Create/update Dockerfile for enterprise
- [ ] Set up Azure Container Registry (ACR)
- [ ] Configure App Service (Web App for Containers)
- [ ] Set up Cosmos DB for MongoDB API
- [ ] Configure Azure Cache for Redis
- [ ] Set up PostgreSQL + pgvector for RAG
- [ ] Configure Key Vault for secrets
- [ ] Custom domain + TLS
- [ ] Deployment slots (staging + production)

## Phase 4: Codebase Pruning

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

## Codespace Smoke Test

- [x] Push to GitHub (Menotron/LibreChat, branch enterprise/phase4-pruning)
- [x] Launch Codespace, npm ci + build
- [x] Create admin user, start backend
- [x] Login works (smenon@glanbia.net)
- [x] Fix 502 (set port to Public)
- [x] Fix 403 (PAT scope: serving.serving-endpoints-query)
- [x] Fix 404 (model names: databricks-claude-sonnet-4-6 etc.)
- [x] Verify chat completion works with GPT-oss models
- [~] Fix Anthropic model 400 errors (debug logging + dropParams added)
- [ ] Verify Anthropic models work after dropParams fix
- [ ] Verify all models in dropdown
- [ ] Test agents endpoint
