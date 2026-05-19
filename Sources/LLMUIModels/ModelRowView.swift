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

    private func byteCountTitle(_ bytes: Int64?) -> String {
        guard let bytes else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
