# LLMBackendRemote Overview

`LLMBackendRemote` adapts remote providers to generic backend contracts.

The current adapter supports non-streaming and SSE-style generation/chat responses through an injected `HTTPTransport`. Provider wire DTOs remain private to this module.

The first concrete provider integrations are OpenAI Chat Completions and Anthropic Messages. They are exposed as provider-specific `RemoteConfiguration` factories while keeping request and response mapping internal to this backend adapter.
