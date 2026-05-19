# LLMUIObservability Overview

`LLMUIObservability` provides optional backend-agnostic SwiftUI presentation for sanitized runtime telemetry.

The module renders `TelemetryEvent` metadata produced by `LLMRuntimeMetrics.sanitizedMetadata()` and filters to known
numeric runtime keys before display.

It includes both detailed event rows and a compact summary for latest latency, throughput, memory, and recent generation
latency trend.
It also includes a small free-memory indicator view for app headers that already collect device memory facts elsewhere.
