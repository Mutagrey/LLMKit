# Codex Task: Local LLM Architecture Audit and Organic Refactor for iOS SPM

## Context

You are working inside an existing Swift Package / iOS project that already has local LLM support.

Known facts:
- There is already some GGUF support.
- There is already some MLX support.
- Current model settings are confusing or unreliable: context window, max tokens, KV cache, generation limits, runtime choice, memory behavior, etc.
- It is unclear whether GGUF loading uses mmap correctly.
- It is unclear whether Metal acceleration is actually enabled or only implied by settings.
- It is unclear whether models are loaded safely by file path or dangerously copied into memory.
- The project may already have useful architecture that should not be destroyed.
- The goal is not to blindly replace everything, but to evaluate the current approach and organically strengthen it.

Primary target platform:
- iPhone / iOS.
- Local inference must be stable under iOS memory pressure.
- The app must avoid jetsam crashes.
- The architecture should support GGUF, MLX, and future runtime extensions without mixing responsibilities.

Main architectural direction:
- GGUF / llama.cpp should likely become the primary production runtime if the existing project can support it properly.
- MLX should be isolated and treated as optional or experimental unless the audit proves it is stable and memory-safe.
- Prompt/session cache, KV cache policy, memory guard, model profiles, and clear runtime lifecycle should be added where missing.
- MatFormer / Gemma 3n and LLM-in-Flash-like ideas should be represented as future-ready extension points, not fake implementations.

---

# Critical Instruction

Do not start by writing code.

First:
1. Audit the current project.
2. Evaluate whether the architecture proposed below should be followed exactly.
3. Decide whether it is better to:
   - follow the proposed architecture closely,
   - adapt the existing architecture with minimal changes,
   - or keep the current architecture and only add missing safeguards.
4. Write/update architecture documentation.
5. Then implement changes step by step according to that documentation.

The goal is a clean, realistic, maintainable refactor, not a forced rewrite.

---

# Phase 1: Audit Current Implementation

Inspect the project and produce a short audit document before implementation.

Create or update:

```text
Docs/LocalLLMArchitecture.md
```

The first version of this document must include:

## 1. Current architecture summary

Describe what currently exists:

- Package/module structure.
- GGUF integration.
- MLX integration.
- Runtime selection logic.
- Model configuration flow.
- Session lifecycle.
- Memory handling.
- Prompt building.
- Streaming output.
- UI-facing settings.
- Any existing diagnostics or logs.

## 2. GGUF audit

Find and document:

- Which backend is used for GGUF?
  - llama.cpp?
  - llama-cpp-swift?
  - custom C/C++ bridge?
  - another wrapper?
- Is the model loaded by file path?
- Is any large model file read through `Data(contentsOf:)` or equivalent?
- Is mmap supported?
- Is mmap enabled by default?
- Is mmap configurable?
- Is Metal compiled into the backend?
- Is Metal actually used at runtime?
- Are there build flags for Metal?
- Are there runtime options for GPU layers / Metal backend?
- Is streaming implemented?
- Is unload/reset implemented?
- Can two GGUF models be loaded at the same time?

## 3. MLX audit

Find and document:

- Which MLX Swift APIs are used?
- Is MLX memory cache limited centrally?
- Is `Memory.clearCache()` used on unload/reset?
- Is context size controlled?
- Is MLX isolated behind a runtime abstraction?
- Can MLX and GGUF be loaded at the same time?
- Is MLX currently default, optional, or experimental?
- Are MLX failures handled clearly?

## 4. Settings audit

Clarify the current meaning of:

- `context`
- `contextWindow`
- `maxTokens`
- `maxNewTokens`
- `maxInputTokens`
- `batchSize`
- `temperature`
- `topP`
- `repeatPenalty`
- KV cache settings
- prompt/session cache settings, if any

Flag ambiguous names and propose safer names.

Important rule:
- `contextSize` must mean total context window for the session.
- `maxInputTokens` must mean maximum allowed input/prompt tokens.
- `maxNewTokens` must mean maximum generated tokens.
- Avoid ambiguous `maxTokens` unless its meaning is documented and unavoidable.

## 5. Memory audit

Find and document:

- Is process available memory measured?
- Is `os_proc_available_memory()` or equivalent used?
- Is process footprint measured?
- Is system free RAM incorrectly used as the only signal?
- Is memory checked before loading a model?
- Is there a safety reserve?
- Are large temporary copies created?
- Is model unload verified?
- Are caches cleared?

## 6. Architecture risk summary

Classify existing code:

```text
Keep:
- Good parts that should remain.

Refactor:
- Useful parts that need clearer boundaries or safer naming.

Remove:
- Dangerous, duplicated, misleading, or unused parts.

Add:
- Missing pieces required for stability.

Defer:
- Interesting but non-essential future work.
```

---

# Phase 2: Decide Refactor Strategy

After the audit, decide which strategy is appropriate.

Document this in `Docs/LocalLLMArchitecture.md`.

## Strategy A: Follow proposed architecture closely

Use this only if the current implementation is messy, tightly coupled, unsafe, or too hard to extend.

Indicators:
- GGUF and MLX are mixed together.
- UI directly controls runtime internals.
- Settings are ambiguous.
- Models are loaded unsafely.
- No session lifecycle exists.
- No memory guard exists.
- Multiple models can accidentally be loaded.
- Metal/mmap settings are fake or unclear.

## Strategy B: Organic adaptation of current architecture

Prefer this if the existing architecture is mostly good.

Indicators:
- Runtime abstraction already exists.
- Model loading is mostly safe.
- Session manager already exists.
- GGUF and MLX are mostly separated.
- Only settings, memory guard, documentation, and diagnostics are missing.

In this strategy:
- Preserve existing names where they are clear.
- Add missing pieces with minimal disruption.
- Avoid renaming public APIs unless necessary.
- Add compatibility wrappers if names must change.

## Strategy C: Minimal hardening only

Use this only if the current project is already production-grade and only lacks a few safeguards.

Allowed changes:
- Add memory guard.
- Clarify settings.
- Add diagnostics.
- Fix dangerous loading.
- Add documentation.
- Isolate obvious MLX/GGUF lifecycle risks.

Do not do a large refactor under Strategy C.

## Required decision output

Before implementation, write:

```text
Chosen strategy: A / B / C

Reason:
...

What will be changed:
...

What will be preserved:
...

What will be deferred:
...
```

---

# Phase 3: Target Architecture

The target architecture may be followed exactly or adapted to the existing codebase, depending on the chosen strategy.

## 1. High-level structure

Preferred conceptual structure:

```text
App / Feature UI
  ↓
AgentCoordinator or UseCase layer
  ↓
ContextBuilder
  ↓
LLMSessionManager
  ↓
LocalLLMEngine
    ├── LlamaCppRuntime / GGUF / Metal / mmap
    ├── MLXRuntime / optional experimental
    ├── CoreMLRuntime / future optional
    └── RemoteRuntime / fallback optional
```

The exact names may differ if the current project already has good equivalents.

Do not create duplicate abstractions just to match these names.

---

# Phase 4: Runtime Abstraction

There must be a clear boundary between app logic and inference runtime.

Preferred protocol:

```swift
public protocol LocalLLMRuntime: AnyObject {
    var id: String { get }
    var capabilities: RuntimeCapabilities { get }

    func canRun(
        model: LocalModelProfile,
        on device: DeviceProfile
    ) -> RuntimeCompatibility

    func load(
        model: LocalModelProfile,
        options: RuntimeLoadOptions
    ) async throws

    func warmup(
        prompt: PromptPackage?
    ) async throws

    func generate(
        request: LLMRequest
    ) -> AsyncThrowingStream<LLMToken, Error>

    func resetSession() async
    func unload() async
}
```

If a similar protocol already exists:
- keep it if it is clean;
- rename only if necessary;
- add missing requirements;
- avoid duplicate protocol layers.

Capabilities:

```swift
public struct RuntimeCapabilities: Sendable {
    public let supportsGGUF: Bool
    public let supportsMLX: Bool
    public let supportsMMap: Bool
    public let supportsMetal: Bool
    public let supportsPromptCache: Bool
    public let supportsKVCacheQuantization: Bool
    public let supportsMatFormer: Bool
    public let supportsFlashAwareWeights: Bool
}
```

Rules:
- Do not claim support for Metal, mmap, KV quantization, MatFormer, or flash-aware weights unless actually implemented.
- Capability flags must reflect real backend behavior.
- Fake settings are worse than missing settings.

---

# Phase 5: Runtime Implementations

## 1. LlamaCppRuntime / GGUF

This should be the primary production runtime if feasible.

Requirements:
- Load model by file path.
- Do not read large model files into `Data`.
- Use mmap if backend supports it.
- Use Metal if backend is compiled and configured for it.
- Stream tokens.
- Support cancellation.
- Support reset/unload.
- Report metrics.
- Enforce one active model on iPhone.

Check whether Metal is truly available:
- build flags;
- linked libraries;
- backend logs;
- runtime capability;
- actual performance/diagnostic signal if available.

If Metal is not available:
- report `supportsMetal = false`;
- keep CPU path working;
- document how to enable Metal later.

## 2. MLXRuntime

MLX should be isolated behind its own runtime.

Requirements:
- Do not mix MLX lifecycle with GGUF lifecycle.
- Configure MLX memory cache in one central place if MLX is used.
- Clear MLX cache on reset/unload.
- Use small context defaults.
- Treat MLX as optional/experimental unless audit proves it stable.
- Do not allow GGUF and MLX models to remain loaded together on iPhone.

## 3. CoreMLRuntime

Do not implement unless the project already has Core ML LLM support.

Allowed:
- Add a placeholder extension point.
- Add documentation explaining it is future work.

## 4. FlashAwareRuntime

Do not implement full LLM-in-Flash.

Allowed:
- Add a future protocol/extension point only if it fits cleanly.

Important:
- mmap is not LLM-in-Flash.
- mmap only avoids eager full-file loading and lets the OS page data lazily.
- True LLM-in-Flash requires special weight paging/access strategies.

---

# Phase 6: Model Profile System

Models must not be represented only as file paths.

Create or adapt a model profile structure.

Preferred shape:

```swift
public struct LocalModelProfile: Codable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let format: ModelFormat
    public let path: URL

    public let parameterClass: String
    public let quantization: String?
    public let estimatedDiskSizeMB: Int
    public let estimatedRuntimeMemoryMB: Int?

    public let defaultContextSize: Int
    public let maxContextSize: Int
    public let defaultMaxNewTokens: Int

    public let supportsMMap: Bool
    public let supportsPromptCache: Bool
    public let supportsKVCacheQuantization: Bool
    public let supportsMatFormer: Bool
    public let supportsFlashAwareWeights: Bool

    public let recommendedRuntime: RuntimeKind
    public let minDeviceMemoryClass: DeviceMemoryClass
}
```

Enums:

```swift
public enum ModelFormat: String, Codable, Sendable {
    case gguf
    case mlx
    case coreML
    case unknown
}

public enum RuntimeKind: String, Codable, Sendable {
    case llamaCpp
    case mlx
    case coreML
    case remote
}
```

If existing model metadata exists:
- adapt it instead of duplicating it;
- add missing fields gradually;
- keep migration simple.

---

# Phase 7: Settings Policy

Settings must be safe and understandable.

Preferred settings object:

```swift
public struct RuntimeLoadOptions: Sendable {
    public let contextSize: Int
    public let maxNewTokens: Int
    public let useMMap: Bool
    public let useMetal: Bool
    public let kvCachePolicy: KVCachePolicy
    public let promptCachePolicy: PromptCachePolicy
    public let batchPolicy: BatchPolicy
}
```

Rules:
- `contextSize` = total context window.
- `maxNewTokens` = maximum generated tokens.
- Do not use model max context as default.
- Do not expose huge context by default on iPhone.
- UI should expose simple modes, not dangerous raw knobs.

Recommended modes:

```swift
public enum LocalLLMPerformanceMode: String, Codable, Sendable {
    case safe
    case balanced
    case advanced
    case experimental
}
```

Suggested mapping:

```text
safe:
  contextSize: 512–1024
  maxNewTokens: 128
  small models only
  safe KV cache

balanced:
  contextSize: 1024–2048
  maxNewTokens: 256
  GGUF preferred

advanced:
  contextSize: 2048–4096
  maxNewTokens: 512
  memory guard required

experimental:
  MLX, KV quantization, large models, future flash-aware options
```

---

# Phase 8: Memory Guard

Add or adapt a memory guard before model loading.

Responsibilities:
- check process available memory, not only system free RAM;
- estimate model memory;
- estimate KV cache pressure from context;
- apply app/iOS reserve;
- reduce settings if borderline;
- deny loading if unsafe;
- recommend fallback.

Preferred structures:

```swift
public struct DeviceProfile: Sendable {
    public let deviceName: String
    public let physicalMemoryMB: Int
    public let availableProcessMemoryMB: Int?
    public let memoryClass: DeviceMemoryClass
}

public enum DeviceMemoryClass: String, Codable, Sendable {
    case low
    case medium
    case high
    case unknown
}

public struct MemoryDecision: Sendable {
    public let canLoad: Bool
    public let reason: String?
    public let recommendedContextSize: Int
    public let recommendedMaxNewTokens: Int
    public let shouldUseFallback: Bool
}
```

Policy:
- If model is clearly too large, do not load.
- If borderline, lower context and maxNewTokens.
- If still unsafe, fallback to smaller model or remote runtime.
- Never rely only on “free RAM” displayed by the app.
- Use `os_proc_available_memory()` or a wrapper where available.

Remove or isolate dangerous patterns:

```swift
Data(contentsOf: modelURL)
```

for large model files.

---

# Phase 9: KV Cache Policy

Introduce a clear KV cache policy.

```swift
public enum KVCachePolicy: Codable, Sendable {
    case safeF16
    case q8Experimental
    case q4Experimental
    case runtimeDefault
}
```

Rules:
- Safe default first.
- KV quantization must be capability-checked.
- q8 may be tested as memory-saving mode.
- q4 must remain experimental.
- Do not silently enable KV quantization.
- If backend does not support it, return a clear compatibility error or fallback to safe mode.

Diagnostics must record:
- context size;
- KV policy;
- memory before load;
- memory after load;
- memory after first token;
- memory after generation;
- output quality issues if testable.

---

# Phase 10: Prompt / Session Cache

Add prompt/session cache support where appropriate.

Goal:
- cache stable system prompt;
- reuse base prompt/session when model and settings match;
- avoid reprocessing long stable instructions;
- do not cache raw large user data;
- invalidate safely.

Preferred key:

```swift
public struct PromptCacheKey: Hashable, Codable, Sendable {
    public let modelId: String
    public let modelFileHash: String
    public let systemPromptVersion: String
    public let contextSize: Int
    public let kvCachePolicy: String
}
```

Policy:

```swift
public enum PromptCachePolicy: Codable, Sendable {
    case disabled
    case basePromptReadOnly
    case sessionReadWrite
}
```

Rules:
- Cache must be invalidated when model changes.
- Cache must be invalidated when model file hash changes.
- Cache must be invalidated when system prompt changes.
- Cache must not be reused across incompatible context/KV settings.
- Backend-native prompt cache is preferred, but logical session caching is acceptable if native support is unavailable.

---

# Phase 11: Context Builder

If this SPM/project includes CGM or app-specific data, do not pass raw time series directly into the LLM.

Add or adapt:

```swift
public protocol LLMContextBuilder {
    associatedtype Input
    func buildContext(from input: Input) throws -> LLMContextPackage
}
```

The LLM should receive compact structured context, for example:

```json
{
  "period": "last_6h",
  "current_glucose": 6.2,
  "trend": "flat",
  "time_in_range": 94,
  "min": 4.8,
  "max": 8.1,
  "volatility": "low",
  "events": [
    "small post-meal rise at 14:20",
    "stable after 16:00"
  ],
  "question": "Что у меня по сахарам?"
}
```

Benefits:
- less prompt size;
- less KV cache pressure;
- faster answers;
- better quality from smaller models;
- fewer memory problems.

If the current SPM is generic and has no CGM domain layer:
- create generic interfaces only;
- do not invent fake CGM logic.

---

# Phase 12: MatFormer / Gemma 3n Extension Points

Do not fake MatFormer support.

MatFormer is a model architecture feature, not a generic runtime switch.

Add model metadata only if useful:

```swift
public struct MatFormerInfo: Codable, Sendable {
    public let isSupported: Bool
    public let effectiveParameterClass: String?
    public let activeParameterBudget: String?
}
```

Rules:
- Only mark a model as MatFormer-compatible if the model family actually supports it.
- Do not pretend to reduce active parameters unless runtime/model support exists.
- Document this as future-aware metadata, not current magic optimization.

---

# Phase 13: LLM-in-Flash Extension Points

Do not implement LLM-in-Flash from scratch.

Add only clean future extension points if they fit naturally:

```swift
public protocol FlashAwareRuntime: LocalLLMRuntime {
    var supportsPagedWeights: Bool { get }
    var flashCacheBudgetMB: Int { get set }
    func setWeightPagingPolicy(_ policy: WeightPagingPolicy)
}

public enum WeightPagingPolicy: Codable, Sendable {
    case disabled
    case conservative
    case aggressiveExperimental
}
```

Documentation must clearly state:
- mmap is useful but not equivalent to LLM-in-Flash.
- True flash-aware inference requires a specialized runtime.
- Current production path should rely on GGUF/mmap/Metal/prompt cache/memory guard.

---

# Phase 14: Session Manager

Add or adapt a central session manager.

Responsibilities:
- choose runtime;
- choose safe settings;
- enforce one active model;
- run memory guard;
- load model;
- warm up prompt/session cache;
- stream generation;
- cancel generation;
- reset session;
- unload model;
- collect metrics.

Preferred state machine:

```swift
public enum LLMSessionState: Equatable, Sendable {
    case idle
    case checkingMemory
    case loadingModel
    case warmingUp
    case ready
    case generating
    case unloading
    case failed(String)
}
```

Rules:
- No generation before ready.
- Cancel previous generation before starting a new one.
- Do not load a second local model while one is active.
- Always clean up after load/generation failure.
- Runtime internals must not depend on SwiftUI.
- UI observes state but does not control backend internals directly.

---

# Phase 15: Diagnostics and Metrics

Add lightweight diagnostics.

Do not log full prompts or sensitive user content by default.

Collect:

```text
device profile
runtime selected
model selected
model file size
format
quantization
context size
max new tokens
mmap enabled/disabled
Metal enabled/disabled
KV cache policy
prompt cache policy
available process memory before load
memory after load
memory after warmup
memory after first token
memory after generation
load time
warmup time
time to first token
tokens per second
unload result
```

Preferred structure:

```swift
public struct LLMRuntimeMetrics: Sendable {
    public let loadTimeMs: Int?
    public let warmupTimeMs: Int?
    public let timeToFirstTokenMs: Int?
    public let tokensPerSecond: Double?
    public let memoryBeforeLoadMB: Int?
    public let memoryAfterLoadMB: Int?
    public let memoryAfterGenerationMB: Int?
}
```

---

# Phase 16: Error Handling

Use clear runtime errors.

```swift
public enum LocalLLMError: Error, Sendable {
    case modelFileMissing(URL)
    case unsupportedModelFormat(ModelFormat)
    case unsupportedRuntime(RuntimeKind)
    case insufficientMemory(reason: String)
    case metalUnavailable
    case mmapUnavailable
    case incompatibleSettings(reason: String)
    case loadFailed(reason: String)
    case generationFailed(reason: String)
}
```

User-facing messages should be short and actionable.

Example:
```text
This model is too large for the current memory conditions. Try a smaller model or reduce context size.
```

Developer logs can contain detailed diagnostics.

---

# Phase 17: Tests

Add tests where possible.

Minimum pure tests:
1. Model profile parsing.
2. Runtime selection.
3. Settings resolution by performance mode.
4. MemoryGuard decisions.
5. Prompt cache key invalidation.
6. Session state transitions.
7. Deny model load when memory guard rejects it.
8. Do not allow two active local models.
9. `contextSize` is not confused with `maxNewTokens`.
10. Unsupported capability returns clear error.

Separate:
- pure unit tests;
- device integration tests;
- runtime/manual tests.

Do not make CI depend on an actual large model file unless the project already has such infrastructure.

---

# Phase 18: Implementation Order

Implement in small stages.

## Stage 1: Audit and documentation

- Inspect project.
- Create/update `Docs/LocalLLMArchitecture.md`.
- Decide Strategy A/B/C.
- Document what will be preserved and what will change.

No production code changes before this is done.

## Stage 2: Naming and settings cleanup

- Clarify `contextSize`, `maxInputTokens`, `maxNewTokens`.
- Remove or deprecate ambiguous names.
- Add compatibility wrappers if needed.

## Stage 3: Runtime boundaries

- Add/adapt `LocalLLMRuntime`.
- Separate GGUF and MLX lifecycle.
- Ensure UI does not directly control runtime internals.

## Stage 4: Model profiles

- Add/adapt `LocalModelProfile`.
- Add safe defaults.
- Add runtime capability metadata.

## Stage 5: Memory guard

- Add `DeviceProfile`.
- Add process memory measurement.
- Add load decision logic.
- Block unsafe loads.

## Stage 6: GGUF hardening

- Ensure model loading by path.
- Ensure no large `Data(contentsOf:)` loading.
- Add mmap configuration if supported.
- Detect/report Metal honestly.
- Add streaming/reset/unload metrics.

## Stage 7: MLX isolation

- Move MLX behind `MLXRuntime`.
- Add central cache limit/clear logic if applicable.
- Mark as experimental if not proven stable.

## Stage 8: Prompt/session cache

- Add cache key.
- Add base prompt/session cache support where backend allows.
- Add invalidation rules.

## Stage 9: KV cache policy

- Add safe default.
- Add experimental q8/q4 options only behind capability checks.
- Add diagnostics.

## Stage 10: Future extension points

- Add MatFormer/Gemma 3n metadata only.
- Add FlashAwareRuntime placeholder only if clean.
- Document that these are future extensions.

## Stage 11: Tests and final docs

- Add pure unit tests.
- Update architecture docs.
- Add migration notes.
- Add verification checklist.

---

# Phase 19: Verification Checklist

At the end, verify:

- [ ] Architecture decision was documented before refactor.
- [ ] The implementation followed the chosen strategy.
- [ ] Existing useful code was preserved where possible.
- [ ] GGUF and MLX lifecycles are separated.
- [ ] GGUF does not load model files through large `Data` copies.
- [ ] mmap support is used only if actually supported.
- [ ] Metal support is detected/reported honestly.
- [ ] There is a memory guard before model loading.
- [ ] UI settings are safe and understandable.
- [ ] `contextSize` and `maxNewTokens` are clearly separated.
- [ ] Prompt/session cache has safe invalidation.
- [ ] KV cache policy is capability-checked.
- [ ] One active local model is enforced on iPhone.
- [ ] Reset/unload paths exist.
- [ ] Runtime metrics are collected.
- [ ] MLX cache handling is centralized if MLX is used.
- [ ] MatFormer is not faked.
- [ ] LLM-in-Flash is not confused with mmap.
- [ ] Documentation is updated.
- [ ] Tests or testable pure components exist.

---

# Phase 20: Final Response Required From Agent

When finished, provide a summary with:

1. Audit findings.
2. Chosen strategy: A, B, or C.
3. Why this strategy was chosen.
4. What was preserved.
5. What was changed.
6. What was added.
7. What was intentionally deferred.
8. How GGUF is now loaded.
9. Whether mmap is actually supported.
10. Whether Metal is actually supported.
11. How MLX is isolated.
12. How memory guard works.
13. How settings should be used.
14. How to test on iPhone.
15. Remaining risks.

Do not claim that a feature works unless it is actually implemented and verified.
