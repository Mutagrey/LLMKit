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

struct SelectedModelSummaryCard: View {
    let descriptor: ModelDescriptor
    let status: String
    let isAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(descriptor.displayName)
                        .font(.headline)
                    Text(descriptor.source?.repository ?? exampleModelFamilyTitle(descriptor.family))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 12)

                ModelPill(title: isAvailable ? "Ready" : "Not Ready", tint: isAvailable ? .green : .orange)
            }

            FlowLayout(spacing: 8) {
                ModelPill(title: exampleBackendTitle(descriptor.backend), tint: .secondary)
                ModelPill(title: exampleModelFamilyTitle(descriptor.family), tint: .secondary)
                if let quantization = descriptor.quantization?.format {
                    ModelPill(title: quantization, tint: .blue)
                }
            }

            FlowLayout(spacing: 8) {
                if let minimumRAMGB = descriptor.minimumRAMGB {
                    metricPill(systemImage: "memorychip", value: "\(minimumRAMGB) GB RAM")
                }
                if let minimumFreeDiskGB = descriptor.minimumFreeDiskGB {
                    metricPill(systemImage: "internaldrive", value: "\(minimumFreeDiskGB) GB free")
                }
                if let contextWindowTokens = descriptor.contextWindowTokens {
                    metricPill(systemImage: "text.quote", value: "\(contextWindowTokens) ctx")
                }
            }

            if !descriptor.capabilities.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(exampleCapabilityTitles(for: descriptor), id: \.self) { capability in
                        ModelPill(title: capability, tint: .secondary)
                    }
                }
            }

            LabeledContent("Status", value: status)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricPill(systemImage: String, value: String) -> some View {
        Label(value, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct ModelRow: View {
    let descriptor: ModelDescriptor
    let status: String
    let isSystemManaged: Bool
    let isDownloadable: Bool
    let isSelected: Bool
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSystemManaged ? "apple.intelligence" : "cpu")
                .font(.subheadline.weight(.semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(descriptor.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if isSystemManaged {
                        ModelPill(title: "System", tint: .secondary)
                    } else if isDownloadable {
                        ModelPill(title: "Local", tint: .blue)
                    }

                    ModelPill(title: isAvailable ? "Ready" : "Needs Install", tint: isAvailable ? .green : .orange)
                }

                HStack(spacing: 8) {
                    Text(exampleBackendTitle(descriptor.backend))
                    if let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes {
                        Text(exampleByteCountTitle(estimatedDownloadSizeBytes))
                    }
                    if let minimumRAMGB = descriptor.minimumRAMGB {
                        Text("\(minimumRAMGB) GB RAM")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModelPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quinary, in: Capsule(style: .continuous))
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                width = max(width, rowWidth)
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth == 0 ? size.width : spacing + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        width = max(width, rowWidth)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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
