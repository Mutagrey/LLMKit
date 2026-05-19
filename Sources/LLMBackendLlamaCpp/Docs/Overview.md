# LLMBackendLlamaCpp Overview

`LLMBackendLlamaCpp` is the isolated backend adapter for native llama.cpp GGUF text models.

The target is intentionally separate from `LLMBackendMLX` because GGUF and MLX safetensors are different runtime
formats. Model discovery and downloads remain owned by `LLMModelLifecycle`.

GGUF Llama, Qwen, and Gemma text models are loaded by installed file path through llama.cpp. The runtime does not read `.gguf` weights into
`Data`. mmap is requested only when `llama_supports_mmap()` reports support. GPU offload is requested only when
`llama_supports_gpu_offload()` reports support and is disabled on simulator; actual device-level Metal execution still
needs runtime diagnostics before it should be reported as proven.

Chat prompt formatting stays in the backend adapter: Llama uses the existing header template, Qwen uses `<|im_start|>`
turns, Gemma 3 uses `<start_of_turn>`, and Gemma 4 uses `<|turn>`.

KV cache policy is metadata-only in this pass. The backend reports requested and effective policies, but does not enable
experimental q8/q4 cache types until native parameter wiring and device validation are added.

When configured with a `MetricsSink`, the backend records numeric load and generation runtime metrics only. Throughput is
calculated from the native sampled-token count, not from streamed text chunks. Telemetry metadata must not include prompt
text, generated text, chat message content, or tool payloads.
