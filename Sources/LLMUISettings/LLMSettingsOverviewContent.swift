import LLMSettings
import SwiftUI

struct LLMSettingsOverviewContent: View {
    let selectedModelName: String?
    let metadata: String?
    let effectiveInputTokens: Int
    let effectiveOutputTokens: Int
    let isLowMemoryConstrained: Bool
    let recommendation: String?

    private let columns = [
        GridItem(.adaptive(minimum: 94), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            modelSummary

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                metricRow(
                    value: LLMSettingsFormatting.tokenCount(effectiveInputTokens),
                    label: "Context",
                    tint: .blue
                )

                metricRow(
                    value: LLMSettingsFormatting.tokenCount(effectiveOutputTokens),
                    label: "Output",
                    tint: .green
                )

                metricRow(
                    value: isLowMemoryConstrained ? "Limited" : "Normal",
                    label: "Memory",
                    tint: isLowMemoryConstrained ? .orange : .green
                )
            }

            if isLowMemoryConstrained {
                noteRow(
                    systemImage: "exclamationmark.triangle.fill",
                    text: "Low memory mode is limiting context and output.",
                    tint: .orange
                )
            }

            if let recommendation {
                noteRow(
                    systemImage: "lightbulb",
                    text: recommendation,
                    tint: .indigo
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modelSummary: some View {
        HStack(alignment: .top) {
            LLMSettingsChromeIcon(
                systemImage: selectedModelName == nil ? "questionmark.circle" : "cube.box",
                tint: .blue
            )

            VStack(alignment: .leading) {
                Text(selectedModelName ?? "No model selected")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(metadata ?? "Select a model to calculate runtime caps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metricRow(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteRow(systemImage: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
