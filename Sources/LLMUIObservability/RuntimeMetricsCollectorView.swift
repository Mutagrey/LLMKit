import LLMCore
import LLMObservability
import SwiftUI

public struct RuntimeMetricsCollectorView: View {
    private let collector: MetricsCollector
    @State private var events: [TelemetryEvent] = []

    public init(collector: MetricsCollector) {
        self.collector = collector
    }

    public var body: some View {
        VStack(spacing: 0) {
            RuntimeMetricsSummaryView(events: events)
            RuntimeMetricsListView(events: events)
        }
            .task {
                await reload()
            }
            .toolbar {
                Button {
                    Task {
                        await reload()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh runtime metrics")
            }
    }

    @MainActor
    private func reload() async {
        events = await collector.snapshot()
    }
}
