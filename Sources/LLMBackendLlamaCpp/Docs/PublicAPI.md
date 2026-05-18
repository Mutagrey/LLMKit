# LLMBackendLlamaCpp Public API

Public API is limited to `LlamaCppBackend`, `LlamaCppModelSupportMatrix`, `LlamaCppRuntimeConfiguration`, and namespace
markers.

`LlamaCppBackend` conforms to `ModelBackend` and the optional chat-session reset hook. The runtime is backed by the
vendored llama.cpp XCFramework and reports unavailable if that binary module is not linked.
