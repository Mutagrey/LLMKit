# LLMOrchestrator Public API

Public API includes `LLMKitContainer`, factory entry points, `ModelRouter`, `ExecutionPlanner`, `FallbackCoordinator`, and default generation/chat/structured service implementations.

`ModelRouter.plan(requirements:)` returns the ordered candidate set used by runtime services. `DefaultLanguageGenerationService` and `DefaultChatService` check backend availability, then stream through candidates until one completes or all eligible candidates fail. Fallback applies to both backend-emitted failure events and thrown stream errors unless the failure is cancellation, unsupported capabilities, or `ExecutionRequirements.allowsFallback` is `false`.

When `ModelSelectionPolicy.require` is used, router failures distinguish missing catalog entries from capability,
RAM, and offline/remote constraint mismatches so host apps can present actionable setup errors.

`ExecutionPlanner` consumes `DeviceProfile` and `RuntimeConstraints` snapshots to filter descriptors whose
declared minimum RAM class clearly exceeds the current device budget. The RAM class check has tolerance for devices
that report slightly less physical memory than their marketed class, and GGUF/llama.cpp descriptors are not rejected
by declared RAM class. Free-disk requirements are install-time lifecycle constraints, not inference-time routing
gates. For `.fast` quality it prefers lower-footprint models, while `.best` still prefers higher-capacity candidates
that remain eligible.
Callers that want a strict pre-load memory gate can construct `ExecutionPlanner` with
`enforcesProcessMemoryBudget: true`. In that mode, local runtime candidates with estimated resident memory are checked
against a backend-neutral process-memory reserve before routing reaches backend load. For GGUF models, the planner does
not treat the full mmap-backed artifact size as process-resident memory.
`BackendRegistry.prepareForLocalModelExecution(_:)` is the local-runtime cleanup point used by default services before
streaming from a selected local model.

`DefaultStructuredGenerationService` forwards stable execution requirements together with the backend-neutral
`StructuredOutputSchema`. It decodes only strict JSON and performs one prompt-level repair attempt by default, which lets
local completion/chat models participate before a backend adds native schema or tool-protocol support.

`DefaultLanguageGenerationService` and `DefaultChatService` can be constructed with a `SafetyPolicyEvaluating` hook.
Input decisions run before routing and output decisions run before final completion events are emitted.

When `DefaultChatService` is given a `ToolService`, it can auto-expose available tools to the backend, execute requested tool invocations, append tool result turns, and continue the same chat round-trip on the selected model without leaking provider-specific tool DTOs into orchestration.

Domain agents are intentionally composed in the consuming app. The package prepares that path through backend-neutral
`SessionID` propagation, structured JSON requests, chat routing, and safety hooks without owning domain DTOs, memory
schemas, or app-specific prompts.
