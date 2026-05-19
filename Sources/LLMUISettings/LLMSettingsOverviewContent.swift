import LLMSettings
import SwiftUI

struct LLMSettingsOverviewContent: View {
    let selectedModelName: String?
    let metadata: String?
    let effectiveInputTokens: Int
    let effectiveOutputTokens: Int
    let isLowMemoryConstrained: Bool
    let recommendation: String?

    var body: some View {
        VStack(alignment: .leading) {
            modelSummary

            Divider()

            VStack(alignment: .leading) {
                Text("Effective limits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                metricRow(
                    systemImage: "rectangle.stack",
                    title: "Context",
                    value: LLMSettingsFormatting.tokenCount(effectiveInputTokens),
                    subtitle: "Prompt and chat history after model and memory caps",
                    tint: .blue
                )

                metricRow(
                    systemImage: "text.bubble",
                    title: "Output",
                    value: LLMSettingsFormatting.tokenCount(effectiveOutputTokens),
                    subtitle: "Maximum answer length for one response",
                    tint: .green
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

    private func metricRow(systemImage: String, title: String, value: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .top) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(tint)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
