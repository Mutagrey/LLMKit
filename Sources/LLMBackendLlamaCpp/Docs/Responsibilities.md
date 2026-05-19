# LLMBackendLlamaCpp Responsibilities

- Accept backend-neutral Llama GGUF descriptors routed to `BackendKind.llamaCpp`.
- Verify that descriptors point at `.gguf` artifacts before advertising support.
- Own llama.cpp-specific load, unload, streaming, cancellation cleanup, and prompt formatting.
- Configure mmap only when llama.cpp reports support.
- Configure Metal offload through explicit GPU layer settings without claiming runtime proof.
- Keep native llama.cpp symbols and runtime state out of core, orchestration, lifecycle, and UI modules.

This module does not download models, own install state, implement tools, or provide structured-output enforcement.
