import LLMCore
import SwiftUI

public struct RuntimeMetricsSummaryView: View {
    private let summary: RuntimeMetricsSummary
    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 8)
    ]

    public init(events: [TelemetryEvent]) {
        self.summary = RuntimeMetricsSummary(events: events)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if summary.isEmpty {
                Text("No runtime metrics")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    RuntimeMetricSummaryTile(title: "Events", value: "\(summary.eventCount)")
                    ForEach(summary.latestValues) { value in
                        RuntimeMetricSummaryTile(title: value.title, value: value.value)
                    }
                }

                if summary.recentGenerationTimesMilliseconds.count > 1 {
                    RuntimeMetricsTrendView(values: summary.recentGenerationTimesMilliseconds)
                }
            }
        }
        .padding()
    }
}

private struct RuntimeMetricSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontDesign(.monospaced)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private struct RuntimeMetricsTrendView: View {
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generation trend")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: 8, height: barHeight(for: value))
                        .accessibilityLabel("\(Int(value.rounded())) ms")
                }
            }
            .frame(height: 44, alignment: .bottom)
        }
    }

    private func barHeight(for value: Double) -> Double {
        guard let maxValue = values.max(), maxValue > 0 else {
            return 4
        }
        return max(4, min(44, (value / maxValue) * 44))
    }
}

#Preview {
    RuntimeMetricsSummaryView(events: [
        TelemetryEvent(name: "llamaCpp.generation.completed", metadata: [
            "runtime.time_to_first_token_ms": "42",
            "runtime.generation_time_ms": "640",
            "runtime.tokens_per_second": "18.5"
        ]),
        TelemetryEvent(name: "mlx.generation.completed", metadata: [
            "runtime.generation_time_ms": "420",
            "runtime.tokens_per_second": "22.1"
        ])
    ])
}
