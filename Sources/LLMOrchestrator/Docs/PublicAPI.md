# LLMOrchestrator Public API

Public API includes `LLMKitContainer`, factory entry points, `ModelRouter`, `ExecutionPlanner`, `FallbackCoordinator`, and default generation/chat/structured service implementations.

`ModelRouter.plan(requirements:)` returns the ordered candidate set used by runtime services. `DefaultLanguageGenerationService` and `DefaultChatService` check backend availability, then stream through candidates until one completes or all eligible candidates fail. Fallback applies to both backend-emitted failure events and thrown stream errors unless the failure is cancellation, unsupported capabilities, or `ExecutionRequirements.allowsFallback` is `false`.

`ExecutionPlanner` consumes `DeviceProfile` and `RuntimeConstraints` snapshots to filter descriptors whose
declared minimum RAM or free-disk requirements exceed the current device budget. For `.fast` quality it
prefers lower-footprint models, while `.best` still prefers higher-capacity candidates that remain eligible.

`DefaultStructuredGenerationService` forwards stable execution requirements together with the backend-neutral
`StructuredOutputSchema`. It decodes only strict JSON and performs one prompt-level repair attempt by default, which lets
local completion/chat models participate before a backend adds native schema or tool-protocol support.

`DefaultLanguageGenerationService` and `DefaultChatService` can be constructed with a `SafetyPolicyEvaluating` hook.
Input decisions run before routing and output decisions run before final completion events are emitted.

When `DefaultChatService` is given a `ToolService`, it can auto-expose available tools to the backend, execute requested tool invocations, append tool result turns, and continue the same chat round-trip on the selected model without leaking provider-specific tool DTOs into orchestration.

`UserInfoExtractorAgent` and `CGMAnalysisAgent` are thin app-facing helpers over existing structured/chat services. They
provide separate `SessionID` defaults for memory extraction and CGM interpretation while leaving domain memory storage and
metric calculation to the consuming app.
