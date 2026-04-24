import LLMCore
import SwiftUI

struct ChatModelToolbarMenu: View {
    let models: [ModelDescriptor]
    let selectedModel: ModelDescriptor?
    let statusText: String
    let isRefreshing: Bool
    let selectModel: (ModelDescriptor) -> Void

    var body: some View {
        Menu {
            if models.isEmpty {
                Text("No models available")
            } else {
                Section("Models") {
                    ForEach(models, id: \.id) { descriptor in
                        Button {
                            selectModel(descriptor)
                        } label: {
                            modelMenuLabel(for: descriptor)
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .center, spacing: 1) {
                HStack(spacing: 6) {
                    Image(systemName: selectedModelIconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedModelTint)
                    Text(selectedModel?.displayName ?? "Select Model")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(isRefreshing ? "Refreshing…" : statusLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 220)
        }
        .accessibilityLabel("Select model")
    }

    private var statusLine: String {
        guard let selectedModel else {
            return "No model selected"
        }
        return "\(exampleBackendTitle(selectedModel.backend)) · \(statusText)"
    }

    private var selectedModelIconName: String {
        guard let selectedModel else {
            return "cpu"
        }
        return selectedModel.backend == .foundationModels ? "apple.intelligence" : "cpu"
    }

    private var selectedModelTint: Color {
        if statusText == "Available" || statusText == "Ready" || statusText == "Active" {
            return .green
        }
        if statusText.hasPrefix("Downloading") || statusText == "Verifying" || statusText == "Compiling" {
            return .blue
        }
        if statusText.hasPrefix("Failed") {
            return .red
        }
        return .secondary
    }

    @ViewBuilder
    private func modelMenuLabel(for descriptor: ModelDescriptor) -> some View {
        HStack(spacing: 10) {
            Image(systemName: descriptor.id == selectedModel?.id ? "checkmark" : menuIconName(for: descriptor))
                .foregroundStyle(descriptor.id == selectedModel?.id ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.displayName)
                Text(exampleBackendTitle(descriptor.backend))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func menuIconName(for descriptor: ModelDescriptor) -> String {
        descriptor.backend == .foundationModels ? "apple.intelligence" : "cpu"
    }
}
