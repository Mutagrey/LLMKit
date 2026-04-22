import LLMCore
import LLMObservability
import Testing

@Test func metricsCollectorStoresEvents() async {
    let collector = MetricsCollector()
    await collector.record(TelemetryEvent(name: "generation.started"))

    let events = await collector.snapshot()

    #expect(events.map(\.name) == ["generation.started"])
}

@Test func metricsCollectorPreservesRecordAndEmitOrder() async {
    let collector = MetricsCollector()

    await collector.record(TelemetryEvent(traceID: "trace-1", name: "generation.started"))
    await collector.emit(TelemetryEvent(traceID: "trace-1", name: "generation.completed"))

    let events = await collector.snapshot()

    #expect(events.map(\.name) == ["generation.started", "generation.completed"])
    #expect(events.map(\.traceID) == ["trace-1", "trace-1"])
}

@Test func metricsCollectorSnapshotIsAValueSnapshot() async {
    let collector = MetricsCollector()
    await collector.record(TelemetryEvent(name: "first"))

    let firstSnapshot = await collector.snapshot()
    await collector.record(TelemetryEvent(name: "second"))
    let secondSnapshot = await collector.snapshot()

    #expect(firstSnapshot.map(\.name) == ["first"])
    #expect(secondSnapshot.map(\.name) == ["first", "second"])
}

@Test func loggingPolicyExcludesPromptContentByDefault() {
    #expect(LoggingPolicy().includesPromptContent == false)
    #expect(LoggingPolicy(includesPromptContent: true).includesPromptContent == true)
}

@Test func generationTraceGeneratesTraceIDAndKeepsModelID() {
    let generated = GenerationTrace(modelID: "model")
    let explicit = GenerationTrace(traceID: "trace", modelID: "model")

    #expect(generated.traceID.rawValue.isEmpty == false)
    #expect(generated.modelID == "model")
    #expect(explicit.traceID == "trace")
    #expect(explicit.modelID == "model")
}
