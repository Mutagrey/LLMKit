# Local LLM Architecture Audit

## Current Architecture Summary

LLMKit is already split into backend-neutral core/protocol/orchestration/lifecycle/UI modules plus isolated backend adapters. GGUF support lives in `LLMBackendLlamaCpp`; MLX support lives in `LLMBackendMLX`; model download/install state lives in `LLMModelLifecycle`; UI reads public services and descriptors.

Runtime selection is capability/model driven through `ModelRouter`, `ExecutionPlanner`, `BackendRegistry`, and `ModelBackend.availability(for:)`. Session state is held by `LLMSessions`; prompt composition lives in `LLMPrompting`; streaming is represented with `AsyncThrowingStream`.

Settings currently use these meanings:

- `ModelDescriptor.contextWindowTokens`: catalog/model advertised context capacity, not a safe runtime default.
- `LlamaCppRuntimeConfiguration.contextSize`: llama.cpp runtime context used for the loaded context.
- `ExecutionBudget.maxInputTokens`: maximum accepted input/prompt estimate.
- `ExecutionBudget.maxOutputTokens`: maximum generated tokens.
- Remote request `maxTokens` names are provider-wire names only.

## GGUF Audit

GGUF uses a custom llama.cpp bridge through `CLlama`, `llama.xcframework`, `LlamaCppNativeContext`, and `LlamaCppLocalRuntime`.

- Backend: native llama.cpp in `LLMBackendLlamaCpp`.
- Loading: `llama_model_load_from_file(path, modelParameters)` with an installed artifact file path.
- Large copies: no `.gguf` path was found using `Data(contentsOf:)`; model lifecycle integrity checks stream large artifact hashes.
- mmap: llama.cpp headers expose `use_mmap` and `llama_supports_mmap()`, but current runtime did not set `use_mmap` explicitly before this refactor.
- Metal: the vendored framework module maps include `ggml-metal.h` and link `Metal`; runtime requested GPU layers through `n_gpu_layers = 99` when `useMetal` was true, and forced CPU on simulator. It did not expose a runtime diagnostic proving actual Metal execution.
- Streaming: implemented by iterative token sampling and `AsyncThrowingStream`.
- Reset/unload: unload drops actor-held native contexts; chat reset hooks exist but llama.cpp has no retained per-session native chat cache.
- Multiple GGUF models: `maxLoadedModels` defaults to one, but the old runtime allowed raising it. iPhone production policy should keep one active local model.

## MLX Audit

MLX uses ADR-approved `mlx-swift-lm` packages only inside `LLMBackendMLX`.

- APIs: `LLMModelFactory.shared.loadContainer`, `ModelContainer`, `ChatSession`, `GenerateParameters`, `Memory`.
- Memory policy: `MLXMemoryPolicy` centralizes cache limit, cache clearing, max loaded models, chat session retention, KV size/bits, and prefill step size.
- Cache clearing: supported through `Memory.clearCache()` after generation and unload when policy enables it.
- Context/KV control: `GenerateParameters.maxTokens`, `maxKVSize`, `kvBits`, `kvGroupSize`, and `prefillStepSize`.
- Isolation: MLX lifecycle is separate from GGUF lifecycle and hidden behind `ModelBackend`.
- Default status: optional/experimental for iPhone unless a host opts into strict memory policy and device testing.
- Risk: GGUF and MLX can both be registered in one app. Each backend limits its own loaded models, but there was no package-level local-runtime arbiter preventing one GGUF plus one MLX model from being loaded at the same time.

## Memory Audit

Current device profiling recorded OS version, physical memory, CPU count, low-power preference, and free disk. It did not measure available process memory. Existing routing filters descriptors by declared minimum RAM, which is useful but too coarse for iOS memory pressure and does not estimate KV/context pressure.

Dangerous large model file reads were not found in GGUF loading. `Data(contentsOf:)` is used for small manifests/session files and tests, not for loading `.gguf` inference weights.

## Architecture Risk Summary

Keep:

- Current module boundaries and `ModelBackend` abstraction.
- Separate `LLMBackendLlamaCpp` and `LLMBackendMLX`.
- Lifecycle-owned artifacts and streaming artifact integrity verification.
- Existing `ExecutionBudget.maxInputTokens` / `maxOutputTokens` naming.

Refactor:

- Make llama.cpp mmap explicit and capability checked.
- Replace implicit "all GPU layers" Metal behavior with explicit `gpuLayerCount`.
- Add process available memory to device profile.
- Add backend-neutral local runtime memory decisions.
- Document MLX strict memory policy as the recommended iPhone path.

Remove:

- No code removal required in this pass.

Add:

- `DeviceProfile.availableProcessMemoryBytes`.
- `LocalRuntimeMemoryGuard` and related estimate/decision value types.
- `LlamaCppRuntimeConfiguration.useMMap`.
- `LlamaCppRuntimeConfiguration.gpuLayerCount`.
- `LlamaCppRuntimeReport` for honest mmap/GPU-offload reporting.
- `BackendModelUnloading` for releasing other local backend caches before local execution.
- Narrow tests for settings, memory, mmap, and simulator Metal behavior.

Defer:

- Runtime proof that Metal executed a specific graph.
- Prompt/session cache implementation.
- KV cache quantization for llama.cpp.
- MatFormer and LLM-in-Flash extension points. mmap is not LLM-in-Flash.

## Chosen Strategy

Chosen strategy: B, organic adaptation of current architecture.

Reason: the repository already has clean module separation and useful implementations. A forced rewrite would increase surface area without fixing the concrete iOS risks.

What will be changed:

- Document the audit and strategy here.
- Add process-memory facts and a small memory guard.
- Harden llama.cpp mmap and GPU-layer settings.
- Update module docs and focused tests.

What will be preserved:

- `ModelBackend` as the runtime boundary.
- Existing core descriptors, lifecycle artifacts, UI services, and routing flow.
- MLX and GGUF backend separation.

What will be deferred:

- Full local runtime session manager rewrite.
- Native prompt cache.
- Native Metal verification telemetry.
- Real device GGUF smoke tests with large model fixtures.

## Prompt Cache Policy

This pass adds only backend-neutral cache metadata:

- `PromptCachePolicy.disabled`
- `PromptCachePolicy.basePromptReadOnly`
- `PromptCachePolicy.sessionReadWrite`
- `PromptCacheKey`

The default policy is disabled. A cache key is invalidated by changes to model identity, model file hash, system prompt
version, context size, or KV-cache policy. This does not claim native prompt cache support in llama.cpp or MLX; backend
adapters must opt in only when the runtime has real cache behavior to preserve.

## KV Cache Policy

`KVCachePolicy` is the single backend-neutral policy type:

- `.runtimeDefault`
- `.safeF16`
- `.q8Experimental`
- `.q4Experimental`

The default remains `.runtimeDefault`. Quantized q8/q4 policies are explicitly experimental and resolve back to
`.runtimeDefault` unless a backend reports quantized KV cache support. The llama.cpp backend now includes requested and
effective KV policy in `LlamaCppRuntimeReport`, but does not set native `type_k`/`type_v` yet.
