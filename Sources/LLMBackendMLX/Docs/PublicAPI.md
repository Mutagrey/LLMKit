# LLMBackendMLX Public API

Public API is limited to `MLXBackend`, `MLXModelSupportMatrix`, and namespace markers. `MLXBackend` also conforms to the
optional backend reset hook so callers can clear cached native chat sessions through app-facing runtime services.
The support matrix allows text-generation descriptors for Qwen, Gemma, Llama, and Mistral families.
`MLXMemoryPolicy.strictForMemoryConstrainedApps` is the recommended policy for iPhone experiments.

Runtime-specific MLX container/session types remain internal to the backend.
