# LLMBackendRemote Overview

`LLMBackendRemote` adapts remote providers to generic backend contracts.

The current adapter supports non-streaming generation/chat requests through an injected `HTTPTransport`. Provider wire DTOs remain private to this module.
