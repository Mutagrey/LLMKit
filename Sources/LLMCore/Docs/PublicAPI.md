# LLMCore Public API

Public API is limited to stable value types and enums needed across targets.

Downloadable local models are described through backend-neutral metadata on `ModelDescriptor`:
`ModelSource`, `ModelArtifact`, `ModelLicense`, and `Quantization`. These types describe where artifacts come from
without making core depend on any downloader, model hub SDK, or backend runtime.

Streaming helpers include `StreamedTextAccumulator`, a small value type for accumulating text deltas without duplicating ad hoc string state across modules.

Tool calling is described through backend-neutral `ToolDefinition`, `ToolArguments`, `ToolInvocation`, `ToolResult`, `ToolCallID`, `ToolCallReference`, and `ToolValue`.
`ToolArguments` keeps structured values as the source of truth while preserving a string projection for simple executors. `ChatRequest` can carry available tool definitions, and `ChatMessage` can reference a prior tool call when a provider needs an explicit tool result turn.
