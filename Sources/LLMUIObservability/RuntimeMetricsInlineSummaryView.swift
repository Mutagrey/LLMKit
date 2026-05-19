import SwiftUI

public struct RuntimeMetricsInlineSummaryView: View {
    private let summary: RuntimeMetricsSummary

    public init(summary: RuntimeMetricsSummary) {
        self.summary = summary
    }

    public var body: some View {
        if !summary.latestValues.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(summary.latestValues.prefix(3))) { value in
                    Text("\(compactTitle(for: value.title)) \(value.value)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityElement(children: .combine)
        }
    }

    private func compactTitle(for title: String) -> String {
        switch title {
        case "First token":
            "TTFT"
        case "Generation":
            "Gen"
        case "Tokens/sec":
            "TPS"
        case "Memory after generation":
            "Mem"
        default:
            title
        }
    }
}
