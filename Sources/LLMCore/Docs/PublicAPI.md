# LLMCore Public API

Public API is limited to stable value types and enums needed across targets.

Downloadable local models are described through backend-neutral metadata on `ModelDescriptor`:
`ModelSource`, `ModelArtifact`, `ModelLicense`, and `Quantization`. These types describe where artifacts come from
without making core depend on any downloader, model hub SDK, or backend runtime.
`BackendKind.llamaCpp` identifies native llama.cpp GGUF adapters while keeping GGUF file metadata in the same
backend-neutral `ModelArtifact` shape used by other downloadable model formats.

Structured generation uses `StructuredOutputSchema` as the backend-neutral schema contract. It stores a canonical
JSON-schema-like object tree using existing `ToolValue` primitives so schema payloads do not require a second generic
JSON value model inside `LLMCore`.
`StructuredRequest` defaults to `.completion` capability so prompt-validated JSON can route to local models; callers should
request `.structuredOutput` only when they require a backend with native schema enforcement.

`GenerationRequest` can carry an optional `structuredOutputSchema` and exposes `renderedPrompt` for backends that still
need prompt-level JSON guidance while native structured generation adapters are adopted incrementally.
`ExecutionRequirements` carries backend-neutral routing constraints, including `allowsFallback` for flows that must stay
on the explicitly selected model.
KV cache selection is represented by `KVCachePolicy`. Quantized KV policies are explicit experimental values and resolve
back to `.runtimeDefault` unless a backend reports quantized KV support.
Prompt/session cache metadata is represented by `PromptCachePolicy` and `PromptCacheKey`. The default prompt cache policy
is `.disabled`; cache reuse must be keyed by model identity, model file hash, system prompt version, runtime context size,
and typed `KVCachePolicy`.

Catalog metadata includes `ModelCatalogStatus` and `ModelCatalogSourceKind`, which let host apps explain whether a
catalog is local, signed remote, or using a fallback manifest without pulling lifecycle implementation details into UI.

Streaming helpers include `StreamedTextAccumulator`, a small value type for accumulating text deltas without duplicating ad hoc string state across modules.

Tool calling is described through backend-neutral `ToolDefinition`, `ToolArguments`, `ToolInvocation`, `ToolResult`, `ToolCallID`, `ToolCallReference`, and `ToolValue`.
`ToolArguments` keeps structured values as the source of truth while preserving a string projection for simple executors. `ChatRequest` can carry available tool definitions, and `ChatMessage` can reference a prior tool call when a provider needs an explicit tool result turn.

Lifecycle state includes `ModelStorageUsage`, which reports total installed bytes and per-model byte counts without exposing
filesystem paths to UI modules.
