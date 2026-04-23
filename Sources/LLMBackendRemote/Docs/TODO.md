# LLMBackendRemote TODO

- Add OpenAI Responses API style when core request/result semantics are ready for Responses-specific lifecycle and event types.
- Add Anthropic tool block request/response mapping when `LLMTools` integration is ready for provider tool calls.
- Add additional concrete provider-specific mappers only when a provider is selected.
- Add curated model descriptor fixtures only if versioning and freshness policy are documented.
- Add streaming transport support if a future `HTTPTransport` variant exposes incremental network chunks.
