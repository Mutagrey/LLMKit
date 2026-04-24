# LLMOrchestrator Public API

Public API includes `LLMKitContainer`, factory entry points, `ModelRouter`, `ExecutionPlanner`, `FallbackCoordinator`, and default generation/chat/structured service implementations.

`ModelRouter.plan(requirements:)` returns the ordered candidate set used by runtime services. `DefaultLanguageGenerationService` and `DefaultChatService` check backend availability, then stream through candidates until one completes or all eligible candidates fail. Fallback applies to both backend-emitted failure events and thrown stream errors unless the failure is cancellation or unsupported capabilities.

`DefaultStructuredGenerationService` forwards stable execution requirements together with the backend-neutral
`StructuredOutputSchema`. Schema-aware prompt rendering now lives on the core request model so orchestration
does not need provider-specific structured DTOs and backends can still recover native schema metadata later.

When `DefaultChatService` is given a `ToolService`, it can auto-expose available tools to the backend, execute requested tool invocations, append tool result turns, and continue the same chat round-trip on the selected model without leaking provider-specific tool DTOs into orchestration.
