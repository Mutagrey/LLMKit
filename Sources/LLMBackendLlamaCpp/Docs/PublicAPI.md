# LLMBackendLlamaCpp Public API

Public API is limited to `LlamaCppBackend`, `LlamaCppModelSupportMatrix`, `LlamaCppRuntimeConfiguration`,
`LlamaCppRuntimeReport`, and namespace markers.

`LlamaCppBackend` conforms to `ModelBackend` and the optional chat-session reset hook. The runtime is backed by the
vendored llama.cpp XCFramework and reports unavailable if that binary module is not linked. Callers may pass an optional
`MetricsSink`; emitted load and generation telemetry uses `LLMRuntimeMetrics.sanitizedMetadata()` and does not include
prompt or generated text. Generation throughput is calculated from native sampled-token count.

`LlamaCppRuntimeConfiguration` exposes conservative local defaults, explicit mmap preference, explicit Metal/GPU layer
preference, KV cache policy metadata, thread count, batch size, and the one-active-model limit.
`LlamaCppRuntimeReport` reports whether mmap/GPU offload are supported and which settings will be applied. It also reports
requested/effective KV cache policy and falls back from experimental q8/q4 metadata when quantized KV support is not wired.
It does not claim actual Metal execution because that requires device runtime diagnostics.
The backend also supports `BackendModelUnloading` so orchestration can release GGUF contexts before another local backend
runs.
`LlamaCppModelSupportMatrix` accepts backend-local text-only `.gguf` descriptors for Llama, Qwen, and Gemma families.
