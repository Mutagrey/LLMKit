# LLMBackendMLX Public API

Public API is limited to `MLXBackend`, `MLXModelSupportMatrix`, and namespace markers. `MLXBackend` also conforms to the
optional backend reset hook so callers can clear cached native chat sessions through app-facing runtime services.

Runtime-specific MLX container/session types remain internal to the backend.
