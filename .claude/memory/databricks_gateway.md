---
name: Databricks AI Gateway Integration
description: How LibreChat connects to Databricks AI Gateway - URL format, auth, model naming, gotchas
type: reference
---

## Gateway URLs

- **Management UI:** `https://adb-1334844506153603.3.azuredatabricks.net/ml/ai-gateway`
- **Invocation base (for LibreChat):** `https://1334844506153603.3.ai-gateway.azuredatabricks.net/mlflow/v1`
- OpenAI SDK appends `/chat/completions` to baseURL, so DATABRICKS_GATEWAY_URL must end at `/v1`

## Authentication

- PAT token with fine-grained scope: **`serving.serving-endpoints-query`** (minimum for chat)
- Scope `serving.serving-endpoints` needed to list/manage endpoints
- Set as `DATABRICKS_API_KEY` in .env

## Model Names

Model names must match exact Databricks serving endpoint names. List via:
```bash
curl -s -H "Authorization: Bearer $DATABRICKS_API_KEY" \
  "https://adb-1334844506153603.3.azuredatabricks.net/api/2.0/serving-endpoints" \
  | jq -r '.endpoints[].name'
```

Gateway does NOT support `/v1/models` endpoint, so `fetch: true` in librechat.yaml won't work. Must hardcode model list.

## Gotchas

- 403 = wrong PAT scope or expired token
- 404 = model name mismatch (e.g., `claude-sonnet` vs `databricks-claude-sonnet-4-6`)
- 400 = some models (e.g., haiku) may not be OpenAI-compatible on gateway — test each model
- `/v1/models` route does not exist on Databricks gateway — cannot auto-fetch model list
- `auth.json` ENOENT error in logs is Firebase/GCP service key — ignorable for enterprise setup
- Streaming warnings (`field[completion_tokens] already exists`, `non-string content`) are noise from Databricks sending usage in every SSE chunk — functional, just noisy
- Use `databricks-gpt-oss-20b` for titleModel (cheap, confirmed OpenAI-compatible)

## Anthropic Models via Gateway (OpenAI-compatible)

Anthropic models on Databricks AI Gateway accept OpenAI SDK format (pattern 1: `/mlflow/v1/chat/completions`) but are stricter than GPT models about which parameters they accept. Key findings:

- `max_tokens` is **required** by Anthropic — added via `addParams` in librechat.yaml
- `addParams: { max_tokens: 4096 }` routes to LangChain's `modelKwargs` (not `llmConfig`) because `knownOpenAIParams` uses camelCase `maxTokens`; this is fine — modelKwargs get spread into the request body as-is
- `dropParams` must use **camelCase** to match `llmConfig` keys (e.g., `frequencyPenalty` not `frequency_penalty`)
- `user` param is always injected by `initializeCustom` line 170 — drop it if gateway rejects it
- `stream_options` is disabled for custom providers via `streamUsage: false` in `run.ts:352`, but drop as safety net
- `run.ts:353` sets `llmConfig.usage = true` for custom providers — this is a LangChain internal flag, should not leak to API body

## Debug Logging (LLM Requests)

When `DEBUG_LOGGING=true`:
- `config.ts` wraps fetch to log the full request body (minus messages) for every LLM API call → `[LLM Request]`
- `run.ts` logs the llmConfig before it's passed to the agent → `[Agent LLM Config]`
- Use this to see exactly what params are being sent to Databricks when debugging 400 errors

## Future: AgentBricks

LangGraph/Databricks Agent SDK agents served via model serving endpoints can be added to librechat.yaml model list. Any endpoint exposing OpenAI-compatible `/chat/completions` works as a LibreChat custom endpoint model.
