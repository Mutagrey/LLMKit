# CLlama Dependency Rules

`CLlama` must not depend on LLMKit Swift targets.

Only `LLMBackendLlamaCpp` should import `CLlama` directly.
