import LLMCore
import SwiftUI

public struct RuntimeMetricsListView: View {
    private let presentations: [RuntimeMetricsPresentation]

    public init(events: [TelemetryEvent]) {
        self.presentations = RuntimeMetricsPresentation.presentations(from: events)
    }

    public var body: some View {
        List {
            if presentations.isEmpty {
                Text("No runtime metrics")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presentations) { presentation in
                    Section {
                        ForEach(presentation.values) { value in
                            RuntimeMetricValueRow(value: value)
                        }
                    } header: {
                        Text(presentation.title)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.automatic)
    }
}

private struct RuntimeMetricValueRow: View {
    let value: RuntimeMetricValue

    var body: some View {
        HStack(spacing: 12) {
            Text(value.title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value.value)
                .fontDesign(.monospaced)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RuntimeMetricsListView(events: [
        TelemetryEvent(name: "llamaCpp.generation.completed", metadata: [
            "runtime.time_to_first_token_ms": "42",
            "runtime.generation_time_ms": "640",
            "runtime.tokens_per_second": "18.5"
        ])
    ])
}
