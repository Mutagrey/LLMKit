# LLMBackendRemote Overview

`LLMBackendRemote` adapts remote providers to generic backend contracts.

The current adapter supports non-streaming and SSE-style generation/chat responses through an injected `HTTPTransport`. Provider wire DTOs remain private to this module.

The first concrete provider integration is OpenAI Chat Completions. It is exposed as a provider-specific `RemoteConfiguration` factory while keeping request and response mapping internal to this backend adapter.
