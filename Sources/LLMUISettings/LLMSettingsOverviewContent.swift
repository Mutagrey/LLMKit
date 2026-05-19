import LLMSettings
import SwiftUI

public struct LLMSettingsOverviewContent: View {
    private let selectedModelName: String?
    private let metadata: String?
    private let effectiveInputTokens: Int
    private let effectiveOutputTokens: Int
    private let isLowMemoryConstrained: Bool
    private let recommendation: String?

    private let columns = [
        GridItem(.adaptive(minimum: 94), spacing: 10)
    ]

    public init(
        selectedModelName: String?,
        metadata: String?,
        effectiveInputTokens: Int,
        effectiveOutputTokens: Int,
        isLowMemoryConstrained: Bool,
        recommendation: String?
    ) {
        self.selectedModelName = selectedModelName
        self.metadata = metadata
        self.effectiveInputTokens = effectiveInputTokens
        self.effectiveOutputTokens = effectiveOutputTokens
        self.isLowMemoryConstrained = isLowMemoryConstrained
        self.recommendation = recommendation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            modelSummary
            Divider()
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
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

            Divider()
            
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
        HStack(alignment: .center) {
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
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.subheadline.monospacedDigit())
                .fontWeight(.semibold)
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
