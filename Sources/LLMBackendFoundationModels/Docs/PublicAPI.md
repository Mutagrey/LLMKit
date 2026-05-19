# LLMBackendFoundationModels Public API

Public API is limited to generic backend conformers and availability helpers.

`FoundationModelsBackend` conforms to `ModelBackend` for Apple Foundation Models descriptors.

`FoundationModelsRuntimeAvailability` lets host code override runtime availability for tests or app-specific gating. Without an override, the backend probes `SystemLanguageModel.default.availability` where the SDK and OS support it.

Foundation Models chat mapping remains backend-neutral: tool definitions and tool result references are folded into prompt text until a dedicated native tool-calling surface is adopted in this target.

For plain generation and chat, `FoundationModelsBackend` emits incremental `.delta` events from Foundation Models `streamResponse` snapshots. The public stream event shape is unchanged.
Callers may pass an optional `MetricsSink`; emitted generation and chat telemetry uses `LLMRuntimeMetrics.sanitizedMetadata()`
and includes latency fields only. `tokensPerSecond` is not populated because the Foundation Models adapter does not observe
native generated token counts.

Structured generation metadata is preserved on `GenerationRequest`. When a backend-neutral `StructuredOutputSchema`
can be mapped to Foundation Models guided generation, the adapter now uses native `GenerationSchema` APIs and returns
the resulting structured content as JSON text to keep upper layers unchanged. Unsupported schema constructs still fall
back to generic prompt rendering.
