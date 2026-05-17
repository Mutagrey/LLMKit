import LLMCore
import SwiftUI

struct ChatModelToolbarMenu: View {
    let models: [ModelDescriptor]
    let selectedModel: ModelDescriptor?
    let selectedStatusText: String
    let isRefreshing: Bool
    let selectModel: (ModelDescriptor) -> Void
    let statusText: (ModelDescriptor) -> String
    @State private var isPresentingPicker = false

    var body: some View {
        Button {
            isPresentingPicker = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select model")
        .sheet(isPresented: $isPresentingPicker) {
            NavigationStack {
                List {
                    if models.isEmpty {
                        ContentUnavailableView(
                            "No Ready Models",
                            systemImage: "arrow.down.circle",
                            description: Text("Install a model from Models before starting a chat.")
                        )
                    } else {
                        Section("Ready Models") {
                            ForEach(models, id: \.id) { descriptor in
                                Button {
                                    selectModel(descriptor)
                                    isPresentingPicker = false
                                } label: {
                                    modelMenuLabel(for: descriptor)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Chat Model")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isPresentingPicker = false
                        }
                    }
                }
            }
        }
    }

    private var label: some View {
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

            Text(isRefreshing ? "Refreshing..." : statusLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: 220)
    }

    private var statusLine: String {
        guard let selectedModel else {
            return models.isEmpty ? "No ready models" : "No model selected"
        }
        return "\(exampleBackendTitle(selectedModel.backend)) · \(selectedStatusText)"
    }

    private var selectedModelIconName: String {
        guard let selectedModel else {
            return "cpu"
        }
        return selectedModel.backend == .foundationModels ? "apple.intelligence" : "cpu"
    }

    private var selectedModelTint: Color {
        tint(for: selectedStatusText)
    }

    @ViewBuilder
    private func modelMenuLabel(for descriptor: ModelDescriptor) -> some View {
        HStack(spacing: 10) {
            Image(systemName: descriptor.id == selectedModel?.id ? "checkmark" : menuIconName(for: descriptor))
                .foregroundStyle(descriptor.id == selectedModel?.id ? Color.accentColor : tint(for: statusText(descriptor)))

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.displayName)
                Text("\(exampleBackendTitle(descriptor.backend)) · \(statusText(descriptor))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tint(for statusText: String) -> Color {
        if statusText == "Available" || statusText == "Ready" || statusText == "Active" {
            return .green
        }
        if statusText.hasPrefix("Downloading") || statusText == "Downloaded" || statusText == "Verifying" || statusText == "Compiling" {
            return .blue
        }
        if statusText.hasPrefix("Failed") {
            return .red
        }
        if statusText == "Install required" || statusText == "Not installed" || statusText.hasPrefix("Evicted") {
            return .orange
        }
        return .secondary
    }

    private func menuIconName(for descriptor: ModelDescriptor) -> String {
        descriptor.backend == .foundationModels ? "apple.intelligence" : "cpu"
    }
}
