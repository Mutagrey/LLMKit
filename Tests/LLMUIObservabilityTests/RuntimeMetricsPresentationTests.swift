import Foundation
import LLMCore
import LLMUIObservability
import Testing

@Test func runtimeMetricsPresentationKeepsOnlyKnownNumericRuntimeMetadata() throws {
    let event = TelemetryEvent(name: "llamaCpp.generation.completed", metadata: [
        "runtime.generation_time_ms": "250",
        "runtime.tokens_per_second": "20.5",
        "runtime.prompt": "secret prompt",
        "runtime.generated_text": "secret output",
        "runtime.memory_after_generation_bytes": "2048",
        "runtime.invalid_numeric": "not-a-number"
    ])

    let presentation = try #require(RuntimeMetricsPresentation(event: event))

    #expect(presentation.title == "llamaCpp.generation.completed")
    #expect(presentation.values.map(\.title) == ["Generation", "Tokens/sec", "Memory after generation"])
    #expect(presentation.values.map(\.rawValue).contains("secret prompt") == false)
    #expect(presentation.values.map(\.rawValue).contains("secret output") == false)
}

@Test func runtimeMetricsPresentationReturnsNilForEventsWithoutRuntimeMetrics() {
    let event = TelemetryEvent(name: "generation.started", metadata: [
        "prompt": "private"
    ])

    #expect(RuntimeMetricsPresentation(event: event) == nil)
}

@Test func runtimeMetricsSummaryKeepsLatestValuesAndRecentGenerationTrend() {
    let events = [
        TelemetryEvent(name: "llamaCpp.generation.completed", metadata: [
            "runtime.time_to_first_token_ms": "40",
            "runtime.generation_time_ms": "300",
            "runtime.tokens_per_second": "12.0"
        ]),
        TelemetryEvent(name: "mlx.generation.completed", metadata: [
            "runtime.time_to_first_token_ms": "20",
            "runtime.generation_time_ms": "200",
            "runtime.tokens_per_second": "18.0",
            "runtime.memory_after_generation_bytes": "4096"
        ])
    ]

    let summary = RuntimeMetricsSummary(events: events)

    #expect(summary.eventCount == 2)
    #expect(summary.latestValues.map(\.rawValue) == ["20", "200", "18.0", "4096"])
    #expect(summary.recentGenerationTimesMilliseconds == [300, 200])
}
