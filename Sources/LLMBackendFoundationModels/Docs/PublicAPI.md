# LLMBackendFoundationModels Public API

Public API is limited to generic backend conformers and availability helpers.

`FoundationModelsBackend` conforms to `ModelBackend` for Apple Foundation Models descriptors.

`FoundationModelsRuntimeAvailability` lets host code override runtime availability for tests or app-specific gating. Without an override, the backend probes `SystemLanguageModel.default.availability` where the SDK and OS support it.

Foundation Models chat mapping remains backend-neutral: tool definitions and tool result references are folded into prompt text until a dedicated native tool-calling surface is adopted in this target.

Structured generation metadata is preserved on `GenerationRequest`. The current generation path still uses generic
schema-aware prompt rendering until this target adopts a native Foundation Models structured response surface.
