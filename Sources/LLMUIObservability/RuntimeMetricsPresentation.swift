import Foundation
import LLMCore

public struct RuntimeMetricsPresentation: Identifiable, Hashable, Sendable {
    public let id: TelemetryEvent.ID
    public let title: String
    public let createdAt: Date
    public let values: [RuntimeMetricValue]

    public init?(event: TelemetryEvent) {
        let values = Self.values(from: event.metadata)
        guard !values.isEmpty else {
            return nil
        }
        self.id = event.id
        self.title = event.name
        self.createdAt = event.createdAt
        self.values = values
    }

    public static func presentations(from events: [TelemetryEvent]) -> [RuntimeMetricsPresentation] {
        events.compactMap(RuntimeMetricsPresentation.init(event:))
    }

    private static func values(from metadata: [String: String]) -> [RuntimeMetricValue] {
        RuntimeMetricDescriptor.allCases.compactMap { descriptor in
            guard let pair = metadata.first(where: { descriptor.matches($0.key) }) else {
                return nil
            }
            guard Int(pair.value) != nil || Double(pair.value) != nil else {
                return nil
            }
            return RuntimeMetricValue(
                id: pair.key,
                title: descriptor.title,
                value: descriptor.formatted(pair.value),
                rawValue: pair.value
            )
        }
    }
}

public struct RuntimeMetricValue: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let rawValue: String

    public init(id: String, title: String, value: String, rawValue: String) {
        self.id = id
        self.title = title
        self.value = value
        self.rawValue = rawValue
    }
}

private enum RuntimeMetricDescriptor: String, CaseIterable {
    case modelLoadTime = "model_load_time_ms"
    case warmupTime = "warmup_time_ms"
    case timeToFirstToken = "time_to_first_token_ms"
    case generationTime = "generation_time_ms"
    case tokensPerSecond = "tokens_per_second"
    case memoryBeforeLoad = "memory_before_load_bytes"
    case memoryAfterLoad = "memory_after_load_bytes"
    case memoryAfterGeneration = "memory_after_generation_bytes"

    var title: String {
        switch self {
        case .modelLoadTime:
            "Model load"
        case .warmupTime:
            "Warmup"
        case .timeToFirstToken:
            "First token"
        case .generationTime:
            "Generation"
        case .tokensPerSecond:
            "Tokens/sec"
        case .memoryBeforeLoad:
            "Memory before load"
        case .memoryAfterLoad:
            "Memory after load"
        case .memoryAfterGeneration:
            "Memory after generation"
        }
    }

    func matches(_ key: String) -> Bool {
        key == rawValue || key.hasSuffix(".\(rawValue)")
    }

    func formatted(_ rawValue: String) -> String {
        switch self {
        case .modelLoadTime, .warmupTime, .timeToFirstToken, .generationTime:
            return "\(rawValue) ms"
        case .tokensPerSecond:
            return "\(rawValue) tok/s"
        case .memoryBeforeLoad, .memoryAfterLoad, .memoryAfterGeneration:
            guard let bytes = Int64(rawValue) else {
                return rawValue
            }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
        }
    }
}
