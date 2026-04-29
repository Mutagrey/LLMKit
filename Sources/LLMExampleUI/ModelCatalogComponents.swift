import Foundation
import LLMCore
import LLMUIDownloads
import SwiftUI

struct CatalogOverviewCard: View {
    let totalModels: Int
    let readyModels: Int
    let downloadableModels: Int
    let installedModels: Int
    let installedSize: String
    let catalogStatus: ModelCatalogStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(catalogTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(catalogSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let catalogMessage {
                    Text(catalogMessage)
                        .font(.caption2)
                        .foregroundStyle(catalogStatus.source == .fallback ? .orange : .secondary)
                        .lineLimit(2)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    summaryMetric(title: "Total", value: "\(totalModels)")
                    summaryMetric(title: "Ready", value: "\(readyModels)", tint: .green)
                }

                GridRow {
                    summaryMetric(title: "Downloadable", value: "\(downloadableModels)", tint: .blue)
                    summaryMetric(title: "Installed", value: "\(installedModels)", tint: .orange)
                }

                GridRow {
                    summaryMetric(title: "Storage", value: installedSize, tint: .secondary)
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

    private var catalogTitle: String {
        switch catalogStatus.source {
        case .local:
            return "Local Catalog"
        case .remoteVerified:
            return "Remote Catalog"
        case .fallback:
            return "Fallback Catalog"
        }
    }

    private var catalogSubtitle: String {
        switch catalogStatus.source {
        case .local:
            return "A lifecycle-owned catalog of on-device models curated for Apple platforms."
        case .remoteVerified:
            return "Loaded from a live remote catalog and merged with the local fallback models."
        case .fallback:
            return "Remote catalog could not be used, so the demo is showing the local fallback manifest."
        }
    }

    private var catalogMessage: String? {
        guard let message = catalogStatus.message, !message.isEmpty else {
            return nil
        }
        return message
    }
}

struct ExampleModelCard: View {
    let descriptor: ModelDescriptor
    let status: String
    let isAvailable: Bool
    let installState: InstallState?
    let installedSizeBytes: Int64?
    let isInstallButtonDisabled: Bool
    let installAction: (() async -> Void)?
    let cancelAction: (() async -> Void)?
    let infoAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            progressSection
            factsRow
            summarySection
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(descriptor.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    Button(action: infoAction) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Model details")

                }
                Text("\(exampleBackendTitle(descriptor.backend)) · \(exampleModelScore(for: descriptor))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            controls
        }
    }

    private var factsRow: some View {
            HStack(spacing: 8) {
                compactFact(title: exampleModelFamilyTitle(descriptor.family))
                compactFact(title: exampleByteCountTitle(installedSizeBytes ?? descriptor.estimatedDownloadSizeBytes))
                if let minimumRAMGB = descriptor.minimumRAMGB {
                    compactFact(title: "\(minimumRAMGB) GB RAM")
                }
            }
            .padding(.vertical, 1)
    }

    @ViewBuilder
    private var progressSection: some View {
        if let installState, isInstalling(state: installState) {
            ModelInstallProgressView(
                state: installState,
                estimatedTotalBytes: descriptor.estimatedDownloadSizeBytes
            )
            .frame(maxWidth: 320, alignment: .leading)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if !isInstalling {
            Text(exampleModelTraitSummary(for: descriptor))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let installState {
            VStack(alignment: .trailing, spacing: 8) {
                if isInstalling(state: installState), let cancelAction {
                    Button {
                        Task { await cancelAction() }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                } else if !isInstalled(state: installState), let installAction {
                    Button {
                        Task { await installAction() }
                    } label: {
                        Text("Download")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(isInstallButtonDisabled)
                }

                statusBadge
            }
            .font(.caption)

        } else {
            statusBadge
                .font(.caption)

        }
    }

    private var isInstalling: Bool {
        guard let installState else {
            return false
        }
        return isInstalling(state: installState)
    }

    private var statusBadge: some View {
        Text(isAvailable ? "Ready" : status)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor(for: status, isAvailable: isAvailable))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                statusColor(for: status, isAvailable: isAvailable).opacity(0.12),
                in: Capsule(style: .continuous)
            )
            .multilineTextAlignment(.trailing)
    }

    private func compactFact(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08), in: Capsule(style: .continuous))
    }

    private func isInstalled(state: InstallState) -> Bool {
        switch state {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .failed, .evicted:
            return false
        }
    }

    private func isInstalling(state: InstallState) -> Bool {
        switch state {
        case .downloading, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return false
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

private func statusColor(for status: String, isAvailable: Bool) -> Color {
    if isAvailable || status == "Ready" || status == "Active" {
        return .green
    }
    if status.hasPrefix("Downloading") || status == "Downloaded" || status == "Verifying" || status == "Compiling" {
        return .blue
    }
    if status.hasPrefix("Failed") {
        return .red
    }
    if status.hasPrefix("Evicted") || status == "Install required" || status == "Network required" || status == "Not installed" {
        return .orange
    }
    return .secondary
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

func exampleFeatureHighlights(for descriptor: ModelDescriptor) -> [String] {
    var highlights: [String] = []

    if descriptor.tags.contains("fast") || descriptor.tags.contains("starter") || descriptor.tags.contains("iphone-entry") {
        highlights.append("Fast and lightweight")
    }
    if descriptor.tags.contains("balanced") || descriptor.tags.contains("recommended") || descriptor.tags.contains("iphone-recommended") {
        highlights.append("Balanced daily driver")
    }
    if descriptor.tags.contains("quality") || descriptor.tags.contains("pro") || descriptor.tags.contains("iphone-pro") {
        highlights.append("Higher quality output")
    }
    if descriptor.capabilities.contains(.offline) {
        highlights.append("Fully offline")
    }
    if descriptor.capabilities.contains(.streaming) {
        highlights.append("Streams replies")
    }

    return highlights
}

func exampleModelTraitSummary(for descriptor: ModelDescriptor) -> String {
    let highlights = exampleFeatureHighlights(for: descriptor)
    if let first = highlights.first {
        return first
    }

    if let minimumRAMGB = descriptor.minimumRAMGB, minimumRAMGB <= 8 {
        return "Compact local model"
    }
    if descriptor.family == .appleFoundation {
        return "System model managed by Apple"
    }
    return "General-purpose local model"
}

func exampleModelScore(for descriptor: ModelDescriptor) -> String {
    let score: String
    if descriptor.tags.contains("quality") || descriptor.tags.contains("pro") || descriptor.family == .appleFoundation {
        score = "4.9★"
    } else if descriptor.tags.contains("balanced") || descriptor.tags.contains("recommended") || descriptor.tags.contains("iphone-recommended") {
        score = "4.7★"
    } else {
        score = "4.5★"
    }
    return score
}

#Preview {
    ExampleModelCard(
        descriptor: .init(
            id: "test",
            displayName: "Test Model",
            family: .custom("Custom Family"),
            backend: .coreML,
            capabilities: [.offline, .chat],
            minimumRAMGB: 8,
            tags: ["downloadable"]
        ),
        status: "Not installed",
        isAvailable: false,
        installState: .notInstalled,
        installedSizeBytes: nil,
        isInstallButtonDisabled: false,
        installAction: {},
        cancelAction: nil
    ) {}
}
