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
    private let isSelected: Bool
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
        isSelected: Bool = false,
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
        self.isSelected = isSelected
        self.installAction = installAction
        self.cancelAction = cancelAction
        self.deleteAction = deleteAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if shouldShowProgress {
                ModelInstallProgressView(
                    state: state,
                    progressDetail: progressDetail,
                    estimatedTotalBytes: descriptor.estimatedDownloadSizeBytes
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(descriptor.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(descriptorSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Selected")
            }

            if isInstalled {
                Text("Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                controls
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if isInstalling, let cancelAction {
            iconButton(systemName: "pause.fill", tint: .red, label: "Pause download") {
                await cancelAction()
            }
        } else if isPaused {
            iconButton(systemName: "play.fill", tint: .accentColor, label: "Resume download") {
                await installAction()
            }
            .disabled(isInstallButtonDisabled)
        } else if !isInstalled {
            iconButton(systemName: actionSymbol, tint: .accentColor, label: actionTitle) {
                await installAction()
            }
            .disabled(isInstallButtonDisabled)
        }
    }

    private func iconButton(
        systemName: String,
        tint: Color,
        label: String,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(tint)
        .accessibilityLabel(label)
    }

    private var backendTitle: String {
        switch descriptor.backend {
        case .foundationModels:
            return "Foundation Models"
        case .coreML:
            return "Core ML"
        case .mlx:
            return "MLX"
        case .llamaCpp:
            return "llama.cpp"
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

    private var descriptorSubtitle: String {
        [
            byteCountTitle(for: installedSizeBytes ?? descriptor.estimatedDownloadSizeBytes),
            runtimeTitle,
            memoryTitle
        ].joined(separator: " · ")
    }

    private var actionTitle: String {
        if isFailed {
            return "Retry"
        }
        if case .evicted = state {
            return "Restore model"
        }
        return "Download model"
    }

    private var actionSymbol: String {
        if isFailed {
            return "arrow.clockwise"
        }
        return "cloud.arrow.down"
    }

    private var isInstalled: Bool {
        switch state {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .paused, .downloaded, .verifying, .compiling, .failed, .evicted:
            return false
        }
    }

    private var isInstalling: Bool {
        switch state {
        case .downloading, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .paused, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    private var isPaused: Bool {
        if case .paused = state {
            return true
        }
        return false
    }

    private var isFailed: Bool {
        if case .failed = state {
            return true
        }
        return false
    }

    private var shouldShowProgress: Bool {
        switch state {
        case .downloading, .paused, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return false
        }
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
                Text(transferTitle ?? statusTitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(progressTitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: progressTransitionValue))
                    .animation(.easeInOut(duration: 0.2), value: progressTransitionValue)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    Capsule(style: .continuous)
                        .fill(statusColor.opacity(0.85))
                        .frame(width: filledWidth(in: geometry.size.width))
                        .animation(.easeInOut(duration: 0.25), value: progressValue)
                }
            }
            .frame(height: 4)
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
        case .downloading(let progress), .paused(let progress):
            return CGFloat(DownloadProgressPresentation.normalizedFraction(progress))
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

    private var progressTransitionValue: Double {
        Double(progressValue)
    }

    private var statusTitle: String {
        switch state {
        case .notInstalled:
            return "Ready to download"
        case .downloading:
            return "Downloading"
        case .paused:
            return "Paused"
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
        case .downloading(let progress), .paused(let progress):
            return DownloadProgressPresentation.percentTitle(
                for: progress,
                isEstimated: progressDetail?.isEstimated == true
            )
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
        guard isTransferState else {
            return nil
        }
        if let progressDetail,
           let completedBytes = progressDetail.completedBytes,
           let totalBytes = progressDetail.totalBytes,
           totalBytes > 0 {
            return "\(byteCountTitle(for: completedBytes)) of \(byteCountTitle(for: totalBytes))"
        }
        guard let estimatedTotalBytes, estimatedTotalBytes > 0 else {
            return nil
        }
        let progress = progressValue
        let writtenBytes = Int64((Double(progress) * Double(estimatedTotalBytes)).rounded())
        return "\(byteCountTitle(for: writtenBytes)) of \(byteCountTitle(for: estimatedTotalBytes))"
    }

    private var transferTransitionValue: Double {
        Double(transferCompletedBytes ?? 0)
    }

    private var transferCompletedBytes: Int64? {
        guard isTransferState else {
            return nil
        }
        if let completedBytes = progressDetail?.completedBytes {
            return completedBytes
        }
        guard let estimatedTotalBytes, estimatedTotalBytes > 0 else {
            return nil
        }
        return Int64((Double(progressValue) * Double(estimatedTotalBytes)).rounded())
    }

    private var statusColor: Color {
        switch state {
        case .notInstalled:
            return .accentColor
        case .downloading, .downloaded, .verifying, .compiling:
            return .blue
        case .paused:
            return .red
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
        return max(totalWidth * progressValue, 4)
    }

    private var isTransferState: Bool {
        switch state {
        case .downloading, .paused:
            return true
        case .notInstalled, .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    private func byteCountTitle(for bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
