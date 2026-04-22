# LLMBackendRemote Public API

Public API includes remote backend configuration and generic backend conformers.

`RemoteConfiguration` owns endpoint paths and default headers. `RemoteBackend` requires an injected `HTTPTransport` before reporting model availability.

When a response body contains server-sent events, `RemoteBackend` maps text deltas into core streaming events and finishes with the accumulated result.
