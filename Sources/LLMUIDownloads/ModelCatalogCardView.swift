import Foundation
import LLMCore
import SwiftUI

public struct ModelCatalogCardView: View {
    private let descriptor: ModelDescriptor
    private let status: String
    private let isAvailable: Bool
    private let isSelected: Bool
    private let installState: InstallState?
    private let progressDetail: ModelInstallProgress?
    private let installedSizeBytes: Int64?
    private let isInstallButtonDisabled: Bool
    private let selectionAction: (() -> Void)?
    private let installAction: (() async -> Void)?
    private let cancelAction: (() async -> Void)?
    private let deleteAction: (() async -> Void)?
    private let detailsAction: (() -> Void)?

    public init(
        descriptor: ModelDescriptor,
        status: String,
        isAvailable: Bool,
        isSelected: Bool = false,
        installState: InstallState? = nil,
        progressDetail: ModelInstallProgress? = nil,
        installedSizeBytes: Int64? = nil,
        isInstallButtonDisabled: Bool = false,
        selectionAction: (() -> Void)? = nil,
        installAction: (() async -> Void)? = nil,
        cancelAction: (() async -> Void)? = nil,
        deleteAction: (() async -> Void)? = nil,
        detailsAction: (() -> Void)? = nil
    ) {
        self.descriptor = descriptor
        self.status = status
        self.isAvailable = isAvailable
        self.isSelected = isSelected
        self.installState = installState
        self.progressDetail = progressDetail
        self.installedSizeBytes = installedSizeBytes
        self.isInstallButtonDisabled = isInstallButtonDisabled
        self.selectionAction = selectionAction
        self.installAction = installAction
        self.cancelAction = cancelAction
        self.deleteAction = deleteAction
        self.detailsAction = detailsAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            progressSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture {
            guard isAvailable, !isSelected else {
                return
            }
            selectionAction?()
        }
        .swipeActions(edge: .trailing) {
            if let deleteAction {
                Button(role: .destructive) {
                    Task { await deleteAction() }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete model")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(descriptor.displayName)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 5) {
                    Image(systemName: traitSymbolName)
                    Text(descriptorSubtitle)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Selected")
                } else {
                    controls
                }

                if let detailsAction {
                    Button(action: detailsAction) {
                        Image(systemName: "info.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Model details")
                }
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        if let installState, isInstalling(state: installState) {
            ModelInstallProgressView(
                state: installState,
                progressDetail: progressDetail,
                estimatedTotalBytes: descriptor.estimatedDownloadSizeBytes
            )
            .frame(maxWidth: 320, alignment: .leading)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let installState, isInstalling(state: installState), let cancelAction {
            Button {
                Task { await cancelAction() }
            } label: {
                Text("Cancel")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        } else if shouldShowInstallButton, let installAction {
            Button {
                Task { await installAction() }
            } label: {
                Text(installButtonTitle)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(isInstallButtonDisabled)
        } else if isAvailable, let selectionAction {
            Button {
                selectionAction()
            } label: {
                Text("Select")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        } else {
            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(isAvailable ? "Ready" : status)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12), in: Capsule(style: .continuous))
            .multilineTextAlignment(.trailing)
    }

    private var descriptorSubtitle: String {
        [
            byteCountTitle(installedSizeBytes ?? descriptor.estimatedDownloadSizeBytes),
            runtimeTitle,
            memoryTitle
        ].joined(separator: " · ")
    }

    private var runtimeTitle: String {
        guard let quantization = descriptor.quantization else {
            return backendTitle
        }
        if let bits = quantization.bits {
            return "\(backendTitle) \(bits)-bit"
        }
        return "\(backendTitle) \(quantization.format)"
    }

    private var memoryTitle: String {
        guard let minimumRAMGB = descriptor.minimumRAMGB else {
            return "RAM varies"
        }
        return "\(minimumRAMGB) GB RAM"
    }

    private var shouldShowInstallButton: Bool {
        guard let installState else {
            return false
        }
        guard !isInstalling(state: installState) else {
            return false
        }
        return !isInstalled(state: installState)
    }

    private var installButtonTitle: String {
        guard let installState else {
            return "Download"
        }
        if case .failed = installState {
            return "Retry"
        }
        if case .evicted = installState {
            return "Restore"
        }
        return "Download"
    }

    private var statusColor: Color {
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

    private var traitSymbolName: String {
        if descriptor.tags.contains("quality") || descriptor.tags.contains("iphone-pro") {
            return "crown"
        }
        if descriptor.tags.contains("starter") || descriptor.tags.contains("iphone-entry") {
            return "bolt"
        }
        if descriptor.family == .appleFoundation {
            return "sparkles"
        }
        return "cpu"
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

    private func byteCountTitle(_ bytes: Int64?) -> String {
        guard let bytes else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    ModelCatalogCardView(
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
        installAction: {},
        detailsAction: {}
    )
}
