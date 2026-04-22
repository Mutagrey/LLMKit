import LLMCore
import LLMProtocols

public actor MetricsCollector: MetricsSink, TraceEmitter {
    private var events: [TelemetryEvent]

    public init(events: [TelemetryEvent] = []) {
        self.events = events
    }

    public func record(_ event: TelemetryEvent) async {
        events.append(event)
    }

    public func emit(_ event: TelemetryEvent) async {
        events.append(event)
    }

    public func snapshot() -> [TelemetryEvent] {
        events
    }
}

public struct LoggingPolicy: Hashable, Sendable {
    public let includesPromptContent: Bool

    public init(includesPromptContent: Bool = false) {
        self.includesPromptContent = includesPromptContent
    }
}

public struct GenerationTrace: Hashable, Sendable {
    public let traceID: TraceID
    public let modelID: ModelID?

    public init(traceID: TraceID = .generated(), modelID: ModelID? = nil) {
        self.traceID = traceID
        self.modelID = modelID
    }
}
