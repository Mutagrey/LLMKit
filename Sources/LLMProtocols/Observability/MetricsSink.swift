import LLMCore

public protocol MetricsSink: Sendable {
    func record(_ event: TelemetryEvent) async
}

public protocol LoggerSink: Sendable {
    func log(_ message: String, metadata: [String: String]) async
}

public protocol TraceEmitter: Sendable {
    func emit(_ event: TelemetryEvent) async
}
