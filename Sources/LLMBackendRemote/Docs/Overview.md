# LLMBackendRemote Overview

`LLMBackendRemote` adapts remote providers to generic backend contracts.

The current adapter supports non-streaming and SSE-style generation/chat responses through an injected `HTTPTransport`. Provider wire DTOs remain private to this module.

The first concrete provider integrations are OpenAI Chat Completions, OpenAI Responses, and Anthropic Messages. They are exposed as provider-specific `RemoteConfiguration` factories while keeping request and response mapping internal to this backend adapter.

For OpenAI Responses and OpenAI Chat Completions generation, backend-neutral `StructuredOutputSchema` can now be
mapped to the provider's native JSON schema response format instead of relying only on prompt-level JSON instructions.
