import Foundation
import LLMCore
import SwiftUI

struct ModelDownloadRowContent: View {
    let descriptor: ModelDescriptor
    let status: String
    let isAvailable: Bool
    let isSelected: Bool
    let installState: InstallState?
    let progressDetail: ModelInstallProgress?
    let installedSizeBytes: Int64?
    let isInstallButtonDisabled: Bool
    let selectionAction: (() -> Void)?
    let installAction: (() async -> Void)?
    let cancelAction: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                titleBlock

                Spacer(minLength: 8)

                trailingContent
            }

            if let installState, installState.llmUIDownloadsShowsProgress {
                ModelInstallProgressView(
                    state: installState,
                    progressDetail: progressDetail,
                    estimatedTotalBytes: descriptor.estimatedDownloadSizeBytes
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture {
            guard isReady, !isSelected else {
                return
            }
            withAnimation(.snappy(duration: 0.18)) {
                selectionAction?()
            }
        }
        .animation(.snappy(duration: 0.2), value: stateAnimationKey)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(descriptor.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(descriptorSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if isReady {
            HStack(spacing: 6) {
                Text("Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: isSelected)
                        .accessibilityLabel("Selected")
                }
            }
        } else if let action = actionSpec {
            ModelRowActionButton(spec: action)
        } else {
            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(status)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1), in: Capsule(style: .continuous))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.trailing)
    }

    private var actionSpec: ModelRowActionButton.Spec? {
        guard let installState else {
            return nil
        }

        if installState.llmUIDownloadsIsInstalling {
            guard let cancelAction else {
                return nil
            }
            return .init(
                symbol: "pause.fill",
                tint: .red,
                label: "Pause download",
                style: .circle,
                isDisabled: false,
                action: cancelAction
            )
        }

        if installState.llmUIDownloadsIsPaused, let installAction {
            return .init(
                symbol: "play.fill",
                tint: .accentColor,
                label: "Resume download",
                style: .circle,
                isDisabled: isInstallButtonDisabled,
                action: installAction
            )
        }

        guard !installState.llmUIDownloadsIsInstalled, let installAction else {
            return nil
        }

        let symbol = installState.llmUIDownloadsInstallSymbol
        return .init(
            symbol: symbol,
            tint: installState.llmUIDownloadsActionTint,
            label: installState.llmUIDownloadsInstallTitle,
            style: symbol == "icloud.and.arrow.down" ? .plain : .circle,
            isDisabled: isInstallButtonDisabled,
            action: installAction
        )
    }

    private var isReady: Bool {
        installState?.llmUIDownloadsIsInstalled ?? isAvailable
    }

    private var stateAnimationKey: String {
        [
            installState.map(String.init(describing:)) ?? "nil",
            String(isAvailable),
            String(isSelected),
            String(isInstallButtonDisabled)
        ].joined(separator: "|")
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

    private var statusColor: Color {
        if isAvailable || status == "Ready" || status == "Active" {
            return .green
        }
        if status.hasPrefix("Failed") {
            return .red
        }
        if status.hasPrefix("Evicted") || status == "Install required" || status == "Network required" || status == "Not installed" {
            return .orange
        }
        return .secondary
    }

    private func byteCountTitle(_ bytes: Int64?) -> String {
        guard let bytes else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct ModelRowActionButton: View {
    struct Spec {
        enum Style: Equatable {
            case plain
            case circle
        }

        let symbol: String
        let tint: Color
        let label: String
        let style: Style
        let isDisabled: Bool
        let action: () async -> Void
    }

    let spec: Spec
    @State private var effectTrigger = 0

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                effectTrigger += 1
            }
            Task { await spec.action() }
        } label: {
            Image(systemName: spec.symbol)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: effectTrigger)
                .frame(width: buttonSize, height: buttonSize)
                .background {
                    if spec.style == .circle {
                        Circle()
                            .fill(spec.tint.opacity(0.12))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(spec.isDisabled ? Color.secondary : spec.tint)
        .opacity(spec.isDisabled ? 0.45 : 1)
        .disabled(spec.isDisabled)
        .accessibilityLabel(spec.label)
    }

    private var buttonSize: CGFloat {
        switch spec.style {
        case .plain:
            return 26
        case .circle:
            return 28
        }
    }
}

extension InstallState {
    var llmUIDownloadsIsInstalled: Bool {
        switch self {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .paused, .downloaded, .verifying, .compiling, .failed, .evicted:
            return false
        }
    }

    var llmUIDownloadsIsInstalling: Bool {
        switch self {
        case .downloading, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .paused, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    var llmUIDownloadsIsPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }

    var llmUIDownloadsShowsProgress: Bool {
        switch self {
        case .downloading, .paused, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    var llmUIDownloadsInstallTitle: String {
        switch self {
        case .failed:
            return "Retry"
        case .evicted:
            return "Restore model"
        default:
            return "Download model"
        }
    }

    var llmUIDownloadsInstallSymbol: String {
        switch self {
        case .failed:
            return "arrow.clockwise"
        default:
            return "icloud.and.arrow.down"
        }
    }

    var llmUIDownloadsActionTint: Color {
        switch self {
        case .failed:
            return .red
        case .evicted:
            return .orange
        default:
            return .accentColor
        }
    }

    var llmUIDownloadsProgressFraction: Double {
        switch self {
        case .notInstalled, .evicted:
            return 0
        case .downloading(let progress), .paused(let progress):
            return DownloadProgressPresentation.normalizedFraction(progress)
        case .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed:
            return 1
        }
    }

    var llmUIDownloadsProgressStatusTitle: String {
        switch self {
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

    var llmUIDownloadsProgressColor: Color {
        switch self {
        case .notInstalled:
            return .accentColor
        case .downloading, .downloaded, .verifying, .compiling:
            return .blue
        case .paused, .failed:
            return .red
        case .ready, .warming, .active:
            return .green
        case .evicted:
            return .orange
        }
    }

    var llmUIDownloadsIsTransferState: Bool {
        switch self {
        case .downloading, .paused:
            return true
        case .notInstalled, .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }
}
