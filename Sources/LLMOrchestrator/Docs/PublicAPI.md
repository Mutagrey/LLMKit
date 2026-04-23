# LLMOrchestrator Public API

Public API includes `LLMKitContainer`, factory entry points, `ModelRouter`, `ExecutionPlanner`, `FallbackCoordinator`, and default generation/chat/structured service implementations.

`ModelRouter.plan(requirements:)` returns the ordered candidate set used by runtime services. `DefaultLanguageGenerationService` and `DefaultChatService` check backend availability, then stream through candidates until one completes or all eligible candidates fail. Fallback applies to both backend-emitted failure events and thrown stream errors unless the failure is cancellation or unsupported capabilities.
