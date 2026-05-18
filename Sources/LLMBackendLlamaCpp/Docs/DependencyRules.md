# LLMBackendLlamaCpp Dependency Rules

Allowed dependencies:

- `LLMCore`
- `LLMProtocols`
- `LLMModelLifecycle`
- `LLMObservability`
- Foundation and the backend-local llama.cpp native bridge

Forbidden dependencies:

- UI targets
- Orchestration targets
- Other backend targets
- Lifecycle ownership of inference execution
