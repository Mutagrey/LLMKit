import LLMCore
import SwiftUI

public struct ModelDownloadCardView: View {
    private let descriptor: ModelDescriptor
    private let state: InstallState
    private let isInstallButtonDisabled: Bool
    private let installAction: @Sendable () async -> Void

    public init(
        descriptor: ModelDescriptor,
        state: InstallState,
        isInstallButtonDisabled: Bool,
        installAction: @escaping @Sendable () async -> Void
    ) {
        self.descriptor = descriptor
        self.state = state
        self.isInstallButtonDisabled = isInstallButtonDisabled
        self.installAction = installAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            metadata
            ModelInstallProgressView(state: state)
            actionRow
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(descriptor.displayName)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 12)
                Text(backendTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let repository = descriptor.source?.repository {
                Text(repository)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(title: "Quantization", value: descriptor.quantization?.format ?? "Standard")
            metadataRow(title: "Size", value: byteCountTitle(for: descriptor.estimatedDownloadSizeBytes))
            metadataRow(title: "License", value: descriptor.license?.spdxIdentifier ?? descriptor.license?.name ?? "Unspecified")
            metadataRow(title: "Context", value: contextTitle)
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .font(.caption)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Task { await installAction() }
            } label: {
                Label(actionTitle, systemImage: actionSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isInstallButtonDisabled)

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
        return "Download"
    }

    private var actionSymbol: String {
        if isInstalled {
            return "checkmark.circle.fill"
        }
        if isInstalling {
            return "arrow.down.circle.fill"
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

    private func byteCountTitle(for bytes: Int64?) -> String {
        guard let bytes else {
            return "Unknown"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

public struct ModelInstallProgressView: View {
    private let state: InstallState

    public init(state: InstallState) {
        self.state = state
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
            return "\(Int((progress * 100).rounded()))%"
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
}
