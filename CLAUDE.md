# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Enterprise AI Platform

## Vision

This is an **enterprise AI agentic harness** — a governed, branded alternative to ChatGPT and Claude desktop apps for business users. Built on [LibreChat](https://github.com/danny-avila/LibreChat), it provides a unified chat interface, agentic capabilities (MCP, code execution, RAG, custom agents), and enterprise controls — all routed exclusively through **Databricks AI Gateway** for governance, inference tables, and cost tracking.

**We are not building a toy.** This is the organization's primary AI interaction surface. Every decision should optimize for:
- **Reliability** — users depend on this daily; downtime and bugs erode trust
- **Maintainability** — code must be clear enough that any engineer can debug production issues at 2am
- **Scalability** — architecture must handle growth from pilot team to full organization
- **Security** — enterprise data flows through this; auth, isolation, and audit are non-negotiable
- **Upstream compatibility** — we must stay mergeable with LibreChat to inherit its rapid innovation

## Upstream Relationship

This is a **maintained fork**, not a divergent copy. LibreChat is one of the fastest-moving open-source AI projects — new model support, agent capabilities, MCP integrations, streaming improvements, and bug fixes land regularly. Our strategy:

### What We Customize
- **Auth**: Azure AD SSO only (social logins removed)
- **LLM routing**: Databricks AI Gateway exclusively (provider code config-disabled, not deleted)
- **Branding**: Enterprise visual identity
- **Deployment**: Azure App Service (Fly.io removed, Helm kept)
- **Governance**: Inference tables, audit logging, RBAC

### What We Inherit
- **Everything else.** Agent framework, MCP support, streaming, file handling, UI components, data schemas, conversation management — all upstream. We benefit from their testing, community bug reports, and feature development.

### Merge Strategy
- **Branch**: `enterprise/phase4-pruning` tracks our enterprise changes
- **Upstream remote**: `danny-avila/LibreChat` `main` branch
- **Sync cadence**: Review upstream releases regularly. Cherry-pick or merge when:
  - Security patches or critical bug fixes land
  - New model/provider support we need (e.g., new Claude or GPT models)
  - Agent/MCP framework improvements
  - Streaming or performance fixes
  - Features that align with our roadmap (RAG improvements, RBAC enhancements)
- **Conflict zones**: Changes concentrate in `api/strategies/`, `librechat.yaml`, `.env`, and deleted files (Assistants API, social logins). These are the merge friction points — keep them minimal.
- **Golden rule**: Prefer config-disabling over code-deleting. The less we delete, the fewer conflicts on merge. If upstream adds a feature we don't need, disable it in `librechat.yaml` or `.env` rather than ripping out code.

### Before Merging Upstream
1. Read the upstream changelog / release notes
2. `git fetch upstream && git log upstream/main --oneline -20` — scan for relevant changes
3. Identify conflict-prone files (strategies, config, deleted code)
4. Merge on a throwaway branch first, resolve conflicts, build, test
5. Only fast-forward the enterprise branch after validation

## Enterprise Code Standards

Beyond LibreChat's existing code style (below), enterprise code must also meet:

- **No silent failures.** Errors must be logged with enough context to diagnose in production. Use structured logging (`logger.error` with metadata), not `console.log`.
- **Graceful degradation.** If a non-critical service (Redis cache, Meilisearch) is unavailable, the app should still serve core chat functionality.
- **Configuration over code.** Behavioral differences between environments (dev, staging, prod) must be driven by env vars or `librechat.yaml`, never by code branches checking `NODE_ENV`.
- **Secrets never in code.** All credentials flow through env vars or Key Vault references. No hardcoded URLs, keys, or tokens — even in comments or examples (use `<placeholder>` syntax).
- **Audit trail.** Changes that affect auth, RBAC, or data access must be logged. User-facing actions should be traceable through Databricks inference tables.
- **Defensive at boundaries.** Validate all external input (user requests, Databricks API responses, webhook payloads). Trust internal code paths and framework guarantees.
- **Horizontal-scale ready.** No in-process state that breaks with multiple instances. Sessions in Redis, file uploads in Blob Storage, job coordination through the existing IJobStore/IEventTransport abstractions.

---

## Project Overview (Monorepo)

LibreChat is a monorepo with the following key workspaces:

| Workspace | Language | Side | Dependency | Purpose |
|---|---|---|---|---|
| `/api` | JS (legacy) | Backend | `packages/api`, `packages/data-schemas`, `packages/data-provider`, `@librechat/agents` | Express server — minimize changes here |
| `/packages/api` | **TypeScript** | Backend | `packages/data-schemas`, `packages/data-provider` | New backend code lives here (TS only, consumed by `/api`) |
| `/packages/data-schemas` | TypeScript | Backend | `packages/data-provider` | Database models/schemas, shareable across backend projects |
| `/packages/data-provider` | TypeScript | Shared | — | Shared API types, endpoints, data-service — used by both frontend and backend |
| `/client` | TypeScript/React | Frontend | `packages/data-provider`, `packages/client` | Frontend SPA |
| `/packages/client` | TypeScript | Frontend | `packages/data-provider` | Shared frontend utilities |

`@librechat/agents` is a major backend dependency (upstream maintains it separately).

---

## Workspace Boundaries

- **All new backend code must be TypeScript** in `/packages/api`.
- Keep `/api` changes to the absolute minimum (thin JS wrappers calling into `/packages/api`).
- Database-specific shared logic goes in `/packages/data-schemas`.
- Frontend/backend shared API logic (endpoints, types, data-service) goes in `/packages/data-provider`.
- Build data-provider from project root: `npm run build:data-provider`.

---

## Architecture

### Backend

Express.js server in `/api` acts as a thin JS wrapper. New backend logic lives in `/packages/api` (TypeScript). The server loads middleware in this order: health check → JSON/URL parsing (3mb limit) → mongoSanitize → CORS → cookie parser → optional compression → static file caching → Passport auth → capability context cache → tenant middleware → route handlers → error handler.

**Key route mounts:** `/api/auth`, `/api/admin/*`, `/api/user`, `/api/messages`, `/api/convos`, `/api/assistants`, `/api/agents`, `/api/files`, `/api/config`, `/api/mcp`, `/oauth`. Unmatched routes fall through to the SPA `index.html`.

**`/packages/api` modules:** `acl/` (access control), `admin/`, `agents/`, `app/` (librechat.yaml config), `auth/` (multi-tenant, OpenID, PKCE), `cache/` (Redis or in-memory), `endpoints/` (LLM abstractions), `files/`, `flow/` (agent orchestration), `mcp/`, `middleware/`, `stream/` (resumable SSE), `storage/` (S3/Firebase/local), `tools/`.

### Authentication & Multi-Tenancy

Auth uses Passport.js. **Enterprise deployment**: local (admin break-glass) + OpenID Connect (Azure AD SSO). Social login strategies (Google/GitHub/Discord/Facebook/Apple) have been removed. LDAP and SAML strategies remain in upstream code but are not configured. All strategies are in `/api/server/strategies/`.

Multi-tenant isolation: `tenantContextMiddleware` in `/packages/api/src/middleware/tenant.ts` propagates `req.user.tenantId` into AsyncLocalStorage. A Mongoose plugin reads ALS context to auto-scope all queries to the current tenant. Strict mode (`TENANT_ISOLATION_STRICT=true`) returns 403 for requests without tenantId. Reverse proxy sets `X-Tenant-Id` header.

### Authorization (RBAC)

Three-tier: **Roles** (collections of capabilities) → **Capabilities** (fine-grained permissions like `can_create_agent`) → **Grants** (user/group → role at platform or tenant level). Capability checks are cached per-request via `capabilityContextMiddleware`.

### Streaming (SSE)

Two-phase resumable pattern: (1) Client POSTs to start generation → server creates job with `jobId` → returns `{ jobId }`. (2) Client GETs EventSource at `/api/stream/{jobId}` → server replays buffered events + streams new ones. Navigation away closes SSE but does NOT abort generation. Explicit abort via `/api/abort?jobId=X`.

`GenerationJobManager` in `/packages/api/src/stream/` uses pluggable `IJobStore` (InMemory or Redis) and `IEventTransport` (InMemory or Redis Pub/Sub) for horizontal scaling. Late subscribers reconnect with sync events to prevent duplicates.

### Frontend

React 18 SPA in `/client` with hybrid state management:

- **React Query** (`@tanstack/react-query`) — server state, caching, background refetch. Hooks in `packages/data-provider/src/react-query/`.
- **Recoil** (`client/src/store/`) — ephemeral UI state (atoms/families for per-index state like stop buttons, settings toggles).
- **React Context** (`client/src/Providers/`) — feature-scoped state (ChatContext, AgentsContext, ArtifactContext, etc.).

UI stack: Tailwind CSS + Radix UI (headless accessible components) + Lucide icons + Framer Motion. Code editor: Monaco. Markdown: react-markdown + remark/rehype plugins (syntax highlighting, KaTeX).

SSE hooks in `client/src/hooks/SSE/`: `useResumableSSE.ts` (primary, with auto-reconnection and exponential backoff), `useAdaptiveSSE.ts` (fallback), `useSSE.ts` (legacy simple).

### Configuration

- **`.env`** — server config (HOST, PORT, MONGO_URI), auth provider keys, feature flags (`ALLOW_SOCIAL_LOGIN`, `LDAP_URL`), scaling (`USE_REDIS`), debugging (`DEBUG_LOGGING`, `AGENT_DEBUG_LOGGING`).
- **`librechat.yaml`** — app-level config (Zod-validated in `/packages/data-schemas/src/config/`): endpoint definitions, model settings, file storage strategies, UI customization (welcome message, ToS), feature toggles (agents, prompts, bookmarks). Override location via `CONFIG_PATH` env var.
- **File storage** — pluggable per file type: `fileStrategy: { avatar: "s3", image: "firebase", document: "local" }`. Implementations in `/packages/api/src/storage/`.

### Build Pipeline

Turbo orchestrates parallel cached builds. Dependency graph: `data-provider` (leaf) → `data-schemas` → `packages/api` → (parallel) `packages/client` → `client`. Packages use Rollup (CJS + ESM output). Frontend uses Vite (HMR dev server on port 3090, proxies `/api` to backend on 3080).

---

## Code Style

### Naming and File Organization

- **Single-word file names** whenever possible (e.g., `permissions.ts`, `capabilities.ts`, `service.ts`).
- When multiple words are needed, prefer grouping related modules under a **single-word directory** rather than using multi-word file names (e.g., `admin/capabilities.ts` not `adminCapabilities.ts`).
- The directory already provides context — `app/service.ts` not `app/appConfigService.ts`.

### Structure and Clarity

- **Never-nesting**: early returns, flat code, minimal indentation. Break complex operations into well-named helpers.
- **Functional first**: pure functions, immutable data, `map`/`filter`/`reduce` over imperative loops. Only reach for OOP when it clearly improves domain modeling or state encapsulation.
- **No dynamic imports** unless absolutely necessary.

### DRY

- Extract repeated logic into utility functions.
- Reusable hooks / higher-order components for UI patterns.
- Parameterized helpers instead of near-duplicate functions.
- Constants for repeated values; configuration objects over duplicated init code.
- Shared validators, centralized error handling, single source of truth for business rules.
- Shared typing system with interfaces/types extending common base definitions.
- Abstraction layers for external API interactions.

### Iteration and Performance

- **Minimize looping** — especially over shared data structures like message arrays, which are iterated frequently throughout the codebase. Every additional pass adds up at scale.
- Consolidate sequential O(n) operations into a single pass whenever possible; never loop over the same collection twice if the work can be combined.
- Choose data structures that reduce the need to iterate (e.g., `Map`/`Set` for lookups instead of `Array.find`/`Array.includes`).
- Avoid unnecessary object creation; consider space-time tradeoffs.
- Prevent memory leaks: careful with closures, dispose resources/event listeners, no circular references.

### Type Safety

- **Never use `any`**. Explicit types for all parameters, return values, and variables.
- **Limit `unknown`** — avoid `unknown`, `Record<string, unknown>`, and `as unknown as T` assertions. A `Record<string, unknown>` almost always signals a missing explicit type definition.
- **Don't duplicate types** — before defining a new type, check whether it already exists in the project (especially `packages/data-provider`). Reuse and extend existing types rather than creating redundant definitions.
- Use union types, generics, and interfaces appropriately.
- All TypeScript and ESLint warnings/errors must be addressed — do not leave unresolved diagnostics.

### Comments and Documentation

- Write self-documenting code; no inline comments narrating what code does.
- JSDoc only for complex/non-obvious logic or intellisense on public APIs.
- Single-line JSDoc for brief docs, multi-line for complex cases.
- Avoid standalone `//` comments unless absolutely necessary.

### Import Order

Imports are organized into three sections:

1. **Package imports** — sorted shortest to longest line length (`react` always first).
2. **`import type` imports** — sorted longest to shortest (package types first, then local types; length resets between sub-groups).
3. **Local/project imports** — sorted longest to shortest.

Multi-line imports count total character length across all lines. Consolidate value imports from the same module. Always use standalone `import type { ... }` — never inline `type` inside value imports.

### JS/TS Loop Preferences

- **Limit looping as much as possible.** Prefer single-pass transformations and avoid re-iterating the same data.
- `for (let i = 0; ...)` for performance-critical or index-dependent operations.
- `for...of` for simple array iteration.
- `for...in` only for object property enumeration.

---

## Frontend Rules (`client/src/**/*`)

### Localization

- All user-facing text must use `useLocalize()`.
- Only update English keys in `client/src/locales/en/translation.json` (other languages are automated externally).
- Semantic key prefixes: `com_ui_`, `com_assistants_`, etc.

### Components

- TypeScript for all React components with proper type imports.
- Semantic HTML with ARIA labels (`role`, `aria-label`) for accessibility.
- Group related components in feature directories (e.g., `SidePanel/Memories/`).
- Use index files for clean exports.

### Data Management

- Feature hooks: `client/src/data-provider/[Feature]/queries.ts` → `[Feature]/index.ts` → `client/src/data-provider/index.ts`.
- React Query (`@tanstack/react-query`) for all API interactions; proper query invalidation on mutations.
- QueryKeys and MutationKeys in `packages/data-provider/src/keys.ts`.

### Data-Provider Integration

- Endpoints: `packages/data-provider/src/api-endpoints.ts`
- Data service: `packages/data-provider/src/data-service.ts`
- Types: `packages/data-provider/src/types/queries.ts`
- Use `encodeURIComponent` for dynamic URL parameters.

### Performance

- Prioritize memory and speed efficiency at scale.
- Cursor pagination for large datasets.
- Proper dependency arrays to avoid unnecessary re-renders.
- Leverage React Query caching and background refetching.

---

## Development Commands

| Command | Purpose |
|---|---|
| `npm run smart-reinstall` | Install deps (if lockfile changed) + build via Turborepo |
| `npm run reinstall` | Clean install — wipe `node_modules` and reinstall from scratch |
| `npm run backend` | Start the backend server |
| `npm run backend:dev` | Start backend with file watching (development) |
| `npm run build` | Build all compiled code via Turborepo (parallel, cached) |
| `npm run frontend` | Build all compiled code sequentially (legacy fallback) |
| `npm run frontend:dev` | Start frontend dev server with HMR (port 3090, requires backend running) |
| `npm run build:data-provider` | Rebuild `packages/data-provider` after changes |
| `npm run lint` | ESLint across all workspaces |
| `npm run lint:fix` | Auto-fix lint errors |

- Node.js: v20.19.0+ or ^22.12.0 or >= 23.0.0
- Database: MongoDB
- Backend runs on `http://localhost:3080/`; frontend dev server on `http://localhost:3090/`

---

## Testing

- Framework: **Jest**, run per-workspace.
- Run tests from their workspace directory: `cd api && npx jest <pattern>`, `cd packages/api && npx jest <pattern>`, etc.
- Frontend tests: `__tests__` directories alongside components; use `test/layout-test-utils` for rendering.
- Cover loading, success, and error states for UI/data flows.

### Philosophy

- **Real logic over mocks.** Exercise actual code paths with real dependencies. Mocking is a last resort.
- **Spies over mocks.** Assert that real functions are called with expected arguments and frequency without replacing underlying logic.
- **MongoDB**: use `mongodb-memory-server` for a real in-memory MongoDB instance. Test actual queries and schema validation, not mocked DB calls.
- **MCP**: use real `@modelcontextprotocol/sdk` exports for servers, transports, and tool definitions. Mirror real scenarios, don't stub SDK internals.
- Only mock what you cannot control: external HTTP APIs, rate-limited services, non-deterministic system calls.
- Heavy mocking is a code smell, not a testing strategy.

### E2E Tests (Playwright)

- Config: `e2e/playwright.config.local.ts` (local), `e2e/playwright.config.ts` (CI).
- Specs: `e2e/specs/*.spec.ts` — landing, messages, settings, keys, navigation, a11y.
- Auth state reused from `e2e/storageState.json`. Tests run against a real backend.
- `npm run e2e` (headless), `npm run e2e:headed` (visible browser), `npm run e2e:debug` (PWDEBUG=1).
- `npm run e2e:a11y` runs accessibility audits via `@axe-core/playwright`.
- `npm run e2e:codegen` generates test code from browser interactions.

---

## Formatting

Fix all formatting lint errors (trailing spaces, tabs, newlines, indentation) using auto-fix when available. All TypeScript/ESLint warnings and errors **must** be resolved.

## Memory & Context

Before starting work, read:

- `.claude/memory/MEMORY.md` — index of all local memory files
- `planner.md` — current goals and open decisions
- `tasks.md` — current task state

Keep these files updated as work progresses.

Always use project memory files in .claude over user level memory and plan files in ~/.claude

## Commit Discipline

Commit after a complete **plan -> implement -> validate** cycle. Do not commit minor intermediate edits. Commits represent coherent, reviewable progress. One feature or substantial task = one commit boundary.

## Upstream Awareness

When modifying any file, consider:
- **Is this file likely to change upstream?** If yes, minimize our diff. Add config switches rather than rewriting logic.
- **Are we duplicating something upstream already solved?** Check the latest upstream before building from scratch.
- **Will this survive a merge?** Isolated additions (new files, config) merge cleanly. Inline edits to hot upstream files cause conflicts.

Files with high upstream churn (expect merge conflicts): `package.json`, `api/server/index.js`, `packages/api/src/endpoints/`, `client/src/components/Chat/`, `packages/data-provider/src/`. Touch these with surgical precision.

Files we own entirely (no upstream conflicts): `librechat.yaml`, `.env.enterprise`, `Dockerfile.enterprise`, `scripts/`, `docker-compose.azure.yml`, `.claude/`, `planner.md`, `tasks.md`.

## Behaviour

- Read existing files before writing code.
- Prefer editing over rewriting.
- Do not re-read files unless they may have changed since last read.
- Test before declaring done.
- Be concise in output, thorough in reasoning.
- No openers, closers, or filler.
- When adding enterprise features, isolate them in new files or behind env var gates where possible — this keeps upstream merges clean.
- User instructions override this file.
