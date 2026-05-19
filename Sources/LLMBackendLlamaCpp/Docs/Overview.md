# LLMBackendLlamaCpp Overview

`LLMBackendLlamaCpp` is the isolated backend adapter for native llama.cpp GGUF text models.

The target is intentionally separate from `LLMBackendMLX` because GGUF and MLX safetensors are different runtime
formats. Model discovery and downloads remain owned by `LLMModelLifecycle`.

GGUF models are loaded by installed file path through llama.cpp. The runtime does not read `.gguf` weights into
`Data`. mmap is requested only when `llama_supports_mmap()` reports support. Metal offload is configured through an
explicit GPU layer count and is disabled on simulator; actual device-level Metal execution still needs runtime
diagnostics before it should be reported as proven.
