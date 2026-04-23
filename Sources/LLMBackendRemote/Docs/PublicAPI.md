# LLMBackendRemote Public API

Public API includes remote backend configuration and generic backend conformers.

`RemoteConfiguration` owns endpoint paths and default headers. `RemoteBackend` requires an injected `HTTPTransport` before reporting model availability.

`RemoteConfiguration.openAI(apiKey:organizationID:projectID:baseURL:)` creates an OpenAI Chat Completions configuration with provider headers and `chat/completions` paths for both generic generation prompts and chat requests. The API key is only stored in default request headers; callers remain responsible for loading and protecting it outside the package.

`RemoteConfiguration.openAIResponses(apiKey:organizationID:projectID:baseURL:)` creates an OpenAI Responses configuration with provider headers and `responses` paths. Generation requests use a string `input`; chat requests use backend-neutral messages, optional tool definitions, and top-level `instructions` for system/developer content.

`RemoteConfiguration.anthropic(apiKey:version:defaultMaxTokens:baseURL:)` creates an Anthropic Messages configuration with `x-api-key`, `anthropic-version`, `/messages` paths, and the default `max_tokens` required by Anthropic request bodies. System and developer chat messages are mapped into Anthropic's top-level `system` field, and backend-neutral tool definitions are mapped into Anthropic's `tools`.

`RemoteModelDescriptors` provides provider-specific convenience builders for regular `ModelDescriptor` values. It does not own catalog state or register models globally.

`RemoteAPIStyle` selects the request mapping strategy. The default remains generic completions/chat mapping; OpenAI can use Chat Completions or Responses request and response shapes; Anthropic uses Messages request and response shapes.

When a response body contains server-sent events, `RemoteBackend` maps text deltas into core streaming events and finishes with the accumulated result. For OpenAI Responses and Anthropic Messages, tool call items are mapped into backend-neutral `ToolInvocation` events before completion. Streams that complete without text or tool calls fail with a backend-neutral mapping error.

OpenAI-compatible response fields for `usage` and `finish_reason`, OpenAI Responses fields for semantic text deltas and function calls, and Anthropic-compatible fields for `usage`, `stop_reason`, and `tool_use`, are mapped into `UsageMetrics`, `StreamFinishReason`, and backend-neutral tool events when present.

Provider HTTP errors remain surfaced as `BackendError.providerFailed` with a normalized message. When available, provider `message`, `type`, `code`, `param`, and request id fields are included as diagnostic details without exposing provider DTOs publicly.
