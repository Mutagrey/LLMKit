# LLMObservability Public API

Public API includes a lightweight metrics collector and tracing types.

`MetricsCollector` can be passed into backend constructors as a `MetricsSink`:

```swift
let metrics = MetricsCollector()

let foundation = FoundationModelsBackend(metricsSink: metrics)
let mlx = MLXBackend(runtimeAvailable: true, metricsSink: metrics)
let gguf = LlamaCppBackend(runtimeAvailable: true, metricsSink: metrics)
```

Runtime metric metadata is numeric-only. Backends must not record prompt text, generated text, chat content, or tool
payloads. `tokensPerSecond` is emitted only when the backend has a native generated-token count.
