# LLMUIObservability Public API

Public API includes `RuntimeMetricsInlineSummaryView`, `RuntimeMetricsSummaryView`, `RuntimeMetricsListView`, `RuntimeMetricsCollectorView`,
`FreeMemoryIndicatorView`,
`RuntimeMetricsSummary`, `RuntimeMetricsPresentation`, and `RuntimeMetricValue`.

`RuntimeMetricsInlineSummaryView` renders a tiny one-line summary for embedding below chat bubble text.
`RuntimeMetricsSummaryView` renders latest latency, throughput, memory, event count, and a compact generation-latency trend.
`RuntimeMetricsListView` renders a supplied `[TelemetryEvent]`.
`RuntimeMetricsCollectorView` snapshots a `MetricsCollector`, shows the summary and list, and exposes a refresh toolbar action.
`RuntimeMetricsPresentation` filters metadata to known numeric runtime keys before values reach SwiftUI.
Metric values are formatted with bounded precision, compact seconds for long millisecond spans, compact throughput, and
byte-count titles for memory.
`FreeMemoryIndicatorView` renders a compact backend-neutral free-memory label from host-supplied byte counts.
