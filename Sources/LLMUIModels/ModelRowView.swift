import Foundation
import LLMCore
import SwiftUI

public struct ModelRowView: View {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                titleBlock

                Spacer(minLength: 8)

                trailingContent
            }

            if let rowErrorMessage {
                Text(rowErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let installState, installState.llmUIModelsShowsProgress {
                ModelInstallProgressView(
                    state: installState,
                    progressDetail: progressDetail,
                    estimatedTotalBytes: descriptor.estimatedDownloadSizeBytes
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
        .swipeActions(edge: .trailing) {
            if let deleteAction {
                Button(role: .destructive) {
                    Task { await deleteAction() }
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel("Delete model")
            }
        }
        .swipeActions(edge: .leading) {
            if let detailsAction {
                Button {
                    detailsAction()
                } label: {
                    Image(systemName: "info.circle")
                }
                .tint(.blue)
                .accessibilityLabel("Model details")
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(descriptor.displayName)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                if isReady {
                    Text("Ready")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Text(descriptorSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .contentTransition(.numericText(value: subtitleTransitionValue))
                    .animation(.easeInOut(duration: 0.2), value: subtitleTransitionValue)
            }
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if isReady {
            selectionIndicator
        } else if let action = actionSpec {
            ModelRowActionButton(spec: action)
        } else if rowErrorMessage == nil {
            statusBadge
        }
    }

    private var selectionIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(ModelRowMetrics.largeSymbolFont)
            .foregroundStyle(.green)
            .scaleEffect(isSelected ? 1 : 0.64)
            .opacity(isSelected ? 1 : 0)
            .symbolEffect(.bounce, value: isSelected)
            .accessibilityLabel("Selected")
            .accessibilityHidden(!isSelected)
            .animation(.snappy(duration: 0.24, extraBounce: 0.18), value: isSelected)
            .frame(
                width: ModelRowMetrics.largeSymbolSize,
                height: ModelRowMetrics.largeSymbolSize
            )
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

        if installState.llmUIModelsIsInstalling {
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

        if installState.llmUIModelsIsPaused, let installAction {
            return .init(
                symbol: "play.fill",
                tint: .accentColor,
                label: "Resume download",
                style: .circle,
                isDisabled: isInstallButtonDisabled,
                action: installAction
            )
        }

        guard !installState.llmUIModelsIsInstalled, let installAction else {
            return nil
        }

        let symbol = installState.llmUIModelsInstallSymbol
        return .init(
            symbol: symbol,
            tint: installState.llmUIModelsActionTint,
            label: installState.llmUIModelsInstallTitle,
            style: symbol == "icloud.and.arrow.down" ? .plain : .circle,
            isDisabled: isInstallButtonDisabled,
            action: installAction
        )
    }

    private var isReady: Bool {
        installState?.llmUIModelsIsInstalled ?? isAvailable
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
            sizeSubtitle,
            runtimeTitle,
            memoryTitle
        ].joined(separator: " · ")
    }

    private var sizeSubtitle: String {
        if installState?.llmUIModelsIsInstalled == true {
            return byteCountTitle(installedSizeBytes ?? descriptor.estimatedDownloadSizeBytes)
        }

        if installState?.llmUIModelsIsTransferState == true,
           let completedBytes = downloadedSubtitleBytes {
            let prefix = isDownloadedSubtitleEstimated ? "~" : ""
            return "\(prefix)\(byteCountTitle(completedBytes)) downloaded"
        }

        return byteCountTitle(descriptor.estimatedDownloadSizeBytes)
    }

    private var subtitleTransitionValue: Double {
        Double(subtitleByteValue ?? 0)
    }

    private var subtitleByteValue: Int64? {
        if installState?.llmUIModelsIsInstalled == true {
            return installedSizeBytes ?? descriptor.estimatedDownloadSizeBytes
        }
        if installState?.llmUIModelsIsTransferState == true {
            return downloadedSubtitleBytes ?? descriptor.estimatedDownloadSizeBytes
        }
        return descriptor.estimatedDownloadSizeBytes
    }

    private var downloadedSubtitleBytes: Int64? {
        guard let installState, installState.llmUIModelsIsTransferState else {
            return nil
        }
        guard let totalBytes = progressDetail?.totalBytes ?? descriptor.estimatedDownloadSizeBytes,
              totalBytes > 0 else {
            return progressDetail?.completedBytes
        }

        let progressBytes = Int64((installState.llmUIModelsProgressFraction * Double(totalBytes)).rounded())
        let reportedBytes = progressDetail?.completedBytes ?? 0
        return min(max(progressBytes, reportedBytes), totalBytes)
    }

    private var isDownloadedSubtitleEstimated: Bool {
        progressDetail?.isEstimated ?? (progressDetail?.totalBytes == nil)
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
        ModelFormatting.backendTitle(descriptor.backend)
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

    private var rowErrorMessage: String? {
        if case .failed(let message) = installState {
            return "Failed: \(message)"
        }
        guard status.hasPrefix("Failed") else {
            return nil
        }
        return status
    }

    private func byteCountTitle(_ bytes: Int64?) -> String {
        guard let bytes else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
