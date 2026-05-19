import Foundation
import LLMCore

public struct RuntimeMetricsSummary: Hashable, Sendable {
    public let eventCount: Int
    public let latestValues: [RuntimeMetricValue]
    public let recentGenerationTimesMilliseconds: [Double]

    public init(events: [TelemetryEvent], trendLimit: Int = 8) {
        let presentations = RuntimeMetricsPresentation.presentations(from: events)
        self.eventCount = presentations.count
        self.latestValues = Self.latestValues(from: presentations)
        self.recentGenerationTimesMilliseconds = Self.recentGenerationTimes(
            from: presentations,
            limit: trendLimit
        )
    }

    public var isEmpty: Bool {
        eventCount == 0
    }

    private static func latestValues(from presentations: [RuntimeMetricsPresentation]) -> [RuntimeMetricValue] {
        [
            latestValue(matching: "time_to_first_token_ms", in: presentations),
            latestValue(matching: "generation_time_ms", in: presentations),
            latestValue(matching: "tokens_per_second", in: presentations),
            latestValue(matching: "memory_after_generation_bytes", in: presentations)
        ].compactMap { $0 }
    }

    private static func latestValue(
        matching suffix: String,
        in presentations: [RuntimeMetricsPresentation]
    ) -> RuntimeMetricValue? {
        presentations.reversed().compactMap { presentation in
            presentation.values.first { value in
                value.id == suffix || value.id.hasSuffix(".\(suffix)")
            }
        }.first
    }

    private static func recentGenerationTimes(
        from presentations: [RuntimeMetricsPresentation],
        limit: Int
    ) -> [Double] {
        presentations.suffix(max(1, limit)).compactMap { presentation in
            presentation.values.first { value in
                value.id == "generation_time_ms" || value.id.hasSuffix(".generation_time_ms")
            }.flatMap { Double($0.rawValue) }
        }
    }
}
