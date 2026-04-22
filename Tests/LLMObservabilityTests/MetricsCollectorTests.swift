import LLMCore
import LLMObservability
import Testing

@Test func metricsCollectorStoresEvents() async {
    let collector = MetricsCollector()
    await collector.record(TelemetryEvent(name: "generation.started"))

    let events = await collector.snapshot()

    #expect(events.map(\.name) == ["generation.started"])
}
