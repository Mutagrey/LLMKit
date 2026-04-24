import Foundation
import LLMCore
import SwiftUI

struct CatalogOverviewCard: View {
    let totalModels: Int
    let readyModels: Int
    let downloadableModels: Int
    let installedModels: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Catalog")
                .font(.headline)

            Text("A lifecycle-owned catalog of on-device models curated for Apple platforms.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    summaryMetric(title: "Total", value: "\(totalModels)")
                    summaryMetric(title: "Ready", value: "\(readyModels)", tint: .green)
                }

                GridRow {
                    summaryMetric(title: "Downloadable", value: "\(downloadableModels)", tint: .blue)
                    summaryMetric(title: "Installed", value: "\(installedModels)", tint: .orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryMetric(title: String, value: String, tint: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CurrentModelSummaryRow: View {
    let descriptor: ModelDescriptor
    let status: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(isAvailable ? Color.green : Color.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(exampleBackendTitle(descriptor.backend)) · \(status)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
        }
    }
}

struct ModelDetailView: View {
    let descriptor: ModelDescriptor
    let status: String
    let isAvailable: Bool

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Status", value: isAvailable ? "Ready" : status)
                LabeledContent("Backend", value: exampleBackendTitle(descriptor.backend))
                LabeledContent("Family", value: exampleModelFamilyTitle(descriptor.family))
                LabeledContent("Model ID", value: descriptor.id.rawValue)
            }

            Section("Requirements") {
                LabeledContent("Download", value: exampleByteCountTitle(descriptor.estimatedDownloadSizeBytes))
                if let minimumRAMGB = descriptor.minimumRAMGB {
                    LabeledContent("Memory", value: "\(minimumRAMGB) GB RAM")
                }
                if let minimumFreeDiskGB = descriptor.minimumFreeDiskGB {
                    LabeledContent("Free Disk", value: "\(minimumFreeDiskGB) GB")
                }
                if let contextWindowTokens = descriptor.contextWindowTokens {
                    LabeledContent("Context", value: "\(contextWindowTokens) tokens")
                }
                if let quantization = descriptor.quantization?.format {
                    LabeledContent("Quantization", value: quantization)
                }
            }

            if !descriptor.capabilities.isEmpty {
                Section("Capabilities") {
                    ForEach(exampleCapabilityTitles(for: descriptor), id: \.self) { capability in
                        Text(capability)
                    }
                }
            }

            Section("Source") {
                LabeledContent("Provider", value: sourceProviderTitle)
                if let repository = descriptor.source?.repository {
                    LabeledContent("Repository", value: repository)
                }
                if let revision = descriptor.source?.revision {
                    LabeledContent("Revision", value: String(revision.prefix(12)))
                }
                LabeledContent("License", value: descriptor.license?.spdxIdentifier ?? descriptor.license?.name ?? "Unspecified")
            }
        }
    }

    private var sourceProviderTitle: String {
        guard let provider = descriptor.source?.provider else {
            return "Unknown"
        }

        switch provider {
        case .huggingFace:
            return "Hugging Face"
        case .remoteURL:
            return "Remote URL"
        case .bundled:
            return "Bundled"
        case .custom(let value):
            return value
        }
    }
}

struct ModelRow: View {
    let descriptor: ModelDescriptor
    let status: String
    let isSelected: Bool
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.55))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(exampleBackendTitle(descriptor.backend))
                    Text(exampleModelFamilyTitle(descriptor.family))
                    if let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes {
                        Text(exampleByteCountTitle(estimatedDownloadSizeBytes))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(isAvailable ? "Ready" : status)
                .font(.caption.weight(.medium))
                .foregroundStyle(isAvailable ? .green : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(descriptor.displayName), \(isSelected ? "selected" : "not selected")")
    }
}

func exampleBackendTitle(_ backend: BackendKind) -> String {
    switch backend {
    case .foundationModels:
        return "Foundation Models"
    case .coreML:
        return "Core ML"
    case .mlx:
        return "MLX"
    case .remote:
        return "Remote"
    case .executorch:
        return "ExecuTorch"
    case .onnxRuntime:
        return "ONNX Runtime"
    case .custom(let name):
        return name
    }
}

func exampleModelFamilyTitle(_ family: ModelFamily) -> String {
    switch family {
    case .appleFoundation:
        return "Apple Foundation"
    case .qwen:
        return "Qwen"
    case .gemma:
        return "Gemma"
    case .llama:
        return "Llama"
    case .mistral:
        return "Mistral"
    case .custom(let value):
        return value
    }
}

func exampleByteCountTitle(_ bytes: Int64?) -> String {
    guard let bytes else {
        return "Unknown size"
    }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func exampleCapabilityTitles(for descriptor: ModelDescriptor) -> [String] {
    let preferredOrder: [ModelCapability] = [
        .chat,
        .completion,
        .streaming,
        .structuredOutput,
        .offline,
        .lowLatency,
        .toolCalling,
        .summarization,
        .classification,
        .longContext,
        .multimodalInput
    ]

    let labels: [ModelCapability: String] = [
        .chat: "Chat",
        .completion: "Completion",
        .streaming: "Streaming",
        .structuredOutput: "Structured",
        .offline: "Offline",
        .lowLatency: "Low Latency",
        .toolCalling: "Tools",
        .summarization: "Summaries",
        .classification: "Classification",
        .longContext: "Long Context",
        .multimodalInput: "Multimodal"
    ]

    return preferredOrder.compactMap { capability in
        guard descriptor.capabilities.contains(capability) else {
            return nil
        }
        return labels[capability]
    }
}
