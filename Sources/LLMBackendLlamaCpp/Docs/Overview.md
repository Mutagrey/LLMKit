# LLMBackendLlamaCpp Overview

`LLMBackendLlamaCpp` is the isolated backend adapter for native llama.cpp GGUF text models.

The target is intentionally separate from `LLMBackendMLX` because GGUF and MLX safetensors are different runtime
formats. Model discovery and downloads remain owned by `LLMModelLifecycle`.

GGUF models are loaded by installed file path through llama.cpp. The runtime does not read `.gguf` weights into
`Data`. mmap is requested only when `llama_supports_mmap()` reports support. GPU offload is requested only when
`llama_supports_gpu_offload()` reports support and is disabled on simulator; actual device-level Metal execution still
needs runtime diagnostics before it should be reported as proven.

KV cache policy is metadata-only in this pass. The backend reports requested and effective policies, but does not enable
experimental q8/q4 cache types until native parameter wiring and device validation are added.
