import Foundation
import LLMCore
import SwiftUI

public struct ModelDownloadCardView: View {
    private let descriptor: ModelDescriptor
    private let state: InstallState
    private let progressDetail: ModelInstallProgress?
    private let installedSizeBytes: Int64?
    private let canDeleteArtifacts: Bool
    private let isInstallButtonDisabled: Bool
    private let installAction: @Sendable () async -> Void
    private let cancelAction: (@Sendable () async -> Void)?
    private let deleteAction: (@Sendable () async -> Void)?

    public init(
        descriptor: ModelDescriptor,
        state: InstallState,
        progressDetail: ModelInstallProgress? = nil,
        installedSizeBytes: Int64? = nil,
        canDeleteArtifacts: Bool = false,
        isInstallButtonDisabled: Bool,
        installAction: @escaping @Sendable () async -> Void,
        cancelAction: (@Sendable () async -> Void)? = nil,
        deleteAction: (@Sendable () async -> Void)? = nil
    ) {
        self.descriptor = descriptor
        self.state = state
        self.progressDetail = progressDetail
        self.installedSizeBytes = installedSizeBytes
        self.canDeleteArtifacts = canDeleteArtifacts
        self.isInstallButtonDisabled = isInstallButtonDisabled
        self.installAction = installAction
        self.cancelAction = cancelAction
        self.deleteAction = deleteAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            primaryFacts
            metadata
            ModelInstallProgressView(
                state: state,
                progressDetail: progressDetail,
                estimatedTotalBytes: descriptor.estimatedDownloadSizeBytes
            )
            actionRow
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(descriptor.displayName)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                Spacer(minLength: 12)
                DownloadPill(title: installBadgeTitle, tint: installBadgeTint)
            }

            if let repository = descriptor.source?.repository {
                Text(repository)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var primaryFacts: some View {
        HStack(spacing: 8) {
            fact(backendTitle)
            fact(familyTitle)
            if let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes {
                fact(byteCountTitle(for: estimatedDownloadSizeBytes))
            }
        }
    }

    private func fact(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08), in: Capsule(style: .continuous))
    }

    private var metadata: some View {
        DisclosureGroup("Details") {
            VStack(alignment: .leading, spacing: 8) {
                metadataRow(title: "Quantization", value: descriptor.quantization?.format ?? "Standard")
                metadataRow(title: "Size", value: byteCountTitle(for: descriptor.estimatedDownloadSizeBytes))
                if let installedSizeBytes {
                    metadataRow(title: "Installed Size", value: byteCountTitle(for: installedSizeBytes))
                }
                metadataRow(title: "License", value: descriptor.license?.spdxIdentifier ?? descriptor.license?.name ?? "Unspecified")
                metadataRow(title: "Context", value: contextTitle)
                metadataRow(title: "Provider", value: sourceProviderTitle)
                if let revision = descriptor.source?.revision {
                    metadataRow(title: "Revision", value: String(revision.prefix(10)))
                }
                if let minimumRAMGB = descriptor.minimumRAMGB {
                    metadataRow(title: "Memory", value: "\(minimumRAMGB) GB RAM")
                }
                if let minimumFreeDiskGB = descriptor.minimumFreeDiskGB {
                    metadataRow(title: "Disk", value: "\(minimumFreeDiskGB) GB free")
                }
            }
        }
        .font(.caption)
    }

    private func metadataRow(title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .font(.caption)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if isInstalling, let cancelAction {
                Button(role: .cancel) {
                    Task { await cancelAction() }
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            } else {
                if canDeleteArtifacts, let deleteAction {
                    Button(role: .destructive) {
                        Task { await deleteAction() }
                    } label: {
                        Label(deleteTitle, systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }

                if !isInstalled {
                    Button {
                        Task { await installAction() }
                    } label: {
                        Label(actionTitle, systemImage: actionSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(isInstallButtonDisabled)
                }
            }

            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if isInstalling {
                Label("In progress", systemImage: "arrow.down.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteTitle: String {
        if isInstalled {
            return "Delete"
        }
        return "Clear"
    }

    private var familyTitle: String {
        switch descriptor.family {
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

    private var backendTitle: String {
        switch descriptor.backend {
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
        case .custom(let value):
            return value
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

    private var contextTitle: String {
        if let contextWindowTokens = descriptor.contextWindowTokens {
            return "\(contextWindowTokens) tokens"
        }
        return "Unknown"
    }

    private var actionTitle: String {
        if isInstalled {
            return "Installed"
        }
        if isInstalling {
            return "Downloading"
        }
        if isFailed {
            return "Retry"
        }
        return "Download"
    }

    private var actionSymbol: String {
        if isInstalled {
            return "checkmark.circle.fill"
        }
        if isInstalling {
            return "arrow.down.circle.fill"
        }
        if isFailed {
            return "arrow.clockwise"
        }
        return "arrow.down.circle"
    }

    private var isInstalled: Bool {
        switch state {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .failed, .evicted:
            return false
        }
    }

    private var isInstalling: Bool {
        switch state {
        case .downloading, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    private var isFailed: Bool {
        if case .failed = state {
            return true
        }
        return false
    }

    private var installBadgeTitle: String {
        if isInstalled {
            return "Installed"
        }
        if isInstalling {
            return "In Progress"
        }
        if isFailed {
            return "Failed"
        }
        if case .evicted = state {
            return "Evicted"
        }
        return "Not Installed"
    }

    private var installBadgeTint: Color {
        if isInstalled {
            return .green
        }
        if isInstalling {
            return .blue
        }
        if isFailed {
            return .red
        }
        if case .evicted = state {
            return .secondary
        }
        return .orange
    }

    private func byteCountTitle(for bytes: Int64?) -> String {
        guard let bytes else {
            return "Unknown"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct DownloadPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule(style: .continuous))
    }
}

public struct ModelInstallProgressView: View {
    private let state: InstallState
    private let progressDetail: ModelInstallProgress?
    private let estimatedTotalBytes: Int64?

    public init(state: InstallState, progressDetail: ModelInstallProgress? = nil, estimatedTotalBytes: Int64? = nil) {
        self.state = state
        self.progressDetail = progressDetail
        self.estimatedTotalBytes = estimatedTotalBytes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                Spacer(minLength: 8)
                Text(progressTitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let transferTitle {
                Text(transferTitle)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.16))
                    Capsule(style: .continuous)
                        .fill(statusColor.gradient)
                        .frame(width: filledWidth(in: geometry.size.width))
                }
            }
            .frame(height: 8)
            .clipShape(Capsule(style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Install progress")
            .accessibilityValue(progressTitle)
        }
    }

    private var progressValue: CGFloat {
        switch state {
        case .notInstalled:
            return 0
        case .downloading(let progress):
            return CGFloat(max(0, min(progress, 1)))
        case .downloaded:
            return 1
        case .verifying:
            return 1
        case .compiling:
            return 1
        case .ready, .warming, .active:
            return 1
        case .failed:
            return 1
        case .evicted:
            return 0
        }
    }

    private var statusTitle: String {
        switch state {
        case .notInstalled:
            return "Ready to download"
        case .downloading:
            return "Downloading"
        case .downloaded:
            return "Downloaded"
        case .verifying:
            return "Verifying files"
        case .compiling:
            return "Preparing runtime"
        case .ready:
            return "Ready"
        case .warming:
            return "Warming"
        case .active:
            return "Active"
        case .failed(let message):
            return "Failed: \(message)"
        case .evicted(let reason):
            return "Evicted: \(String(describing: reason))"
        }
    }

    private var progressTitle: String {
        switch state {
        case .downloading(let progress):
            let prefix = progressDetail?.isEstimated == true ? "~" : ""
            return "\(prefix)\(Int((progress * 100).rounded()))%"
        case .notInstalled:
            return "0%"
        case .evicted:
            return "0%"
        case .failed:
            return "Failed"
        case .ready, .warming, .active, .downloaded, .verifying, .compiling:
            return "100%"
        }
    }

    private var transferTitle: String? {
        guard case .downloading = state else {
            return nil
        }
        if let progressDetail,
           let completedBytes = progressDetail.completedBytes,
           let totalBytes = progressDetail.totalBytes,
           totalBytes > 0 {
            let prefix = progressDetail.isEstimated ? "Approx. " : ""
            return "\(prefix)\(byteCountTitle(for: completedBytes)) of \(byteCountTitle(for: totalBytes))"
        }
        guard let estimatedTotalBytes, estimatedTotalBytes > 0 else {
            return nil
        }
        let progress = progressValue
        let writtenBytes = Int64((Double(progress) * Double(estimatedTotalBytes)).rounded())
        return "Approx. \(byteCountTitle(for: writtenBytes)) of \(byteCountTitle(for: estimatedTotalBytes))"
    }

    private var statusColor: Color {
        switch state {
        case .notInstalled:
            return .accentColor
        case .downloading, .downloaded, .verifying, .compiling:
            return .blue
        case .ready, .warming, .active:
            return .green
        case .failed:
            return .red
        case .evicted:
            return .orange
        }
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        guard progressValue > 0 else {
            return 0
        }
        return max(totalWidth * progressValue, 8)
    }

    private func byteCountTitle(for bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
