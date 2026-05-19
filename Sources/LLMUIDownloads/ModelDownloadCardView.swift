import Foundation
import LLMCore
import SwiftUI

public struct ModelDownloadCardView: View {
    private let descriptor: ModelDescriptor
    private let state: InstallState
    private let progressDetail: ModelInstallProgress?
    private let installedSizeBytes: Int64?
    private let isInstallButtonDisabled: Bool
    private let isSelected: Bool
    private let installAction: @Sendable () async -> Void
    private let cancelAction: (@Sendable () async -> Void)?

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
        self.isInstallButtonDisabled = isInstallButtonDisabled
        self.isSelected = isSelected
        self.installAction = installAction
        self.cancelAction = cancelAction
    }

    public var body: some View {
        ModelDownloadRowContent(
            descriptor: descriptor,
            status: state.llmUIDownloadsProgressStatusTitle,
            isAvailable: state.llmUIDownloadsIsInstalled,
            isSelected: isSelected,
            installState: state,
            progressDetail: progressDetail,
            installedSizeBytes: installedSizeBytes,
            isInstallButtonDisabled: isInstallButtonDisabled,
            selectionAction: nil,
            installAction: installAction,
            cancelAction: cancelAction
        )
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
        CGFloat(state.llmUIDownloadsProgressFraction)
    }

    private var progressTransitionValue: Double {
        Double(progressValue)
    }

    private var statusTitle: String {
        state.llmUIDownloadsProgressStatusTitle
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

    private var statusColor: Color {
        state.llmUIDownloadsProgressColor
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        guard progressValue > 0 else {
            return 0
        }
        return max(totalWidth * progressValue, 4)
    }

    private var isTransferState: Bool {
        state.llmUIDownloadsIsTransferState
    }

    private func byteCountTitle(for bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
