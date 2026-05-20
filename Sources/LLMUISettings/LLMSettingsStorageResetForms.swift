import Foundation
import LLMSettings
import LLMUIStorage
import SwiftUI

@MainActor
extension LLMSettingsDetailScreen {
    var storageSections: some View {
        Group {
            if let storageSummary = context.storageSummary {
                Section {
                    LLMSettingsStorageUsageView(summary: storageSummary)
                }
            }

            if !context.storageRows.isEmpty {
                Section {
                    ForEach(context.storageRows) { row in
                        VStack(alignment: .leading) {
                            LabeledContent(row.title, value: row.value)
                            if let detail = row.detail {
                                Text(detail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if hasStorageCleanupActions {
                Section {
                    if actions.clearModelArtifacts != nil {
                        Button(role: .destructive) {
                            pendingStorageCleanupAction = .modelArtifacts
                        } label: {
                            Label("Clear artifacts", systemImage: "shippingbox")
                        }
                    }

                    if actions.clearChatSessions != nil {
                        Button(role: .destructive) {
                            pendingStorageCleanupAction = .chatSessions
                        } label: {
                            Label("Clear chats", systemImage: "bubble.left.and.bubble.right")
                        }
                    }

                    if actions.clearInstalledModels != nil {
                        Button(role: .destructive) {
                            pendingStorageCleanupAction = .installedModels
                        } label: {
                            Label("Clear models", systemImage: "cpu")
                        }
                    }
                } footer: {
                    Text("Cleanup actions are host-owned. Model lifecycle, chat persistence, and artifact files stay outside settings UI.")
                }
            }

            if let openSessionSettings = actions.openSessionSettings {
                Section {
                    Button {
                        openSessionSettings()
                    } label: {
                        Label("Manage chat sessions", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
        }
    }

    private var hasStorageCleanupActions: Bool {
        actions.clearModelArtifacts != nil
            || actions.clearChatSessions != nil
            || actions.clearInstalledModels != nil
    }

    func performStorageCleanup(_ cleanupAction: LLMSettingsStorageCleanupAction) async {
        switch cleanupAction {
        case .modelArtifacts:
            await actions.clearModelArtifacts?()
        case .chatSessions:
            await actions.clearChatSessions?()
        case .installedModels:
            await actions.clearInstalledModels?()
        }
    }

    var resetSections: some View {
        Group {
            Section {
                Menu {
                    ForEach(LLMSettingsPreset.allCases, id: \.self) { preset in
                        Button(LLMSettingsFormatting.title(for: preset)) {
                            settings.applyPreset(preset)
                        }
                    }
                } label: {
                    Label("Apply preset", systemImage: "slider.horizontal.3")
                }
            }

            Section {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    Label("Reset AI settings to recommended defaults", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Section resets keep other groups unchanged. Full reset restores recommended local-first defaults.")
            }
        }
    }
}

enum LLMSettingsStorageCleanupAction: String, Identifiable {
    case modelArtifacts
    case chatSessions
    case installedModels

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .modelArtifacts:
            return "Clear model artifacts?"
        case .chatSessions:
            return "Clear saved chats?"
        case .installedModels:
            return "Clear installed models?"
        }
    }

    var message: String {
        switch self {
        case .modelArtifacts:
            return "This removes partial downloads and temporary artifacts. Installed models and chats are kept."
        case .chatSessions:
            return "This deletes saved chat sessions. Models and model artifacts are kept."
        case .installedModels:
            return "This deletes all installed local models exposed by the host action. You may need to download them again."
        }
    }

    var confirmationButtonTitle: String {
        switch self {
        case .modelArtifacts:
            return "Clear Artifacts"
        case .chatSessions:
            return "Clear Chats"
        case .installedModels:
            return "Clear Models"
        }
    }
}

private struct LLMSettingsStorageUsageView: View {
    let summary: LLMSettingsStorageSummary

    private let columns = [
        GridItem(.adaptive(minimum: 94), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                if let modelCountTitle {
                    metric(value: modelCountTitle, label: "Models", tint: .green, transitionValue: Double(summary.installedModelCount ?? 0))
                }
                if let chatCount = summary.chatCount {
                    metric(value: "\(chatCount)", label: "Chats", tint: .cyan, transitionValue: Double(chatCount))
                }
                metric(
                    value: byteCountTitle(positiveInstalledBytes),
                    label: "Installed",
                    tint: .blue,
                    transitionValue: Double(positiveInstalledBytes)
                )
                metric(
                    value: byteCountTitle(positivePartialArtifactBytes),
                    label: "Artifacts",
                    tint: .orange,
                    transitionValue: Double(positivePartialArtifactBytes)
                )
            }

            storageBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(value: String, label: String, tint: Color, transitionValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText(value: transitionValue))
                .animation(.easeInOut(duration: 0.2), value: transitionValue)

            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var storageBar: some View {
        if let diskUsage {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(storageStatusTitle) · \(diskUsedTitle)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.numericText(value: Double(diskUsage.usedBytes)))
                        .animation(.easeInOut(duration: 0.2), value: diskUsage.usedBytes)
                    Spacer(minLength: 8)
                    Text(diskFreeTitle)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(diskTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.numericText(value: Double(diskUsage.availableBytes)))
                        .animation(.easeInOut(duration: 0.2), value: diskUsage.availableBytes)
                }

                StorageUsageBarView(
                    segments: diskChartSegments,
                    totalBytes: diskUsage.capacityBytes,
                    accessibilityLabel: "Settings storage usage",
                    accessibilityValue: "\(diskFreeTitle), \(diskUsedTitle)"
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Artifact storage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(artifactStorageTitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(artifactStorageBytes)))
                        .animation(.easeInOut(duration: 0.2), value: artifactStorageBytes)
                }

                StorageUsageBarView(
                    segments: artifactChartSegments,
                    totalBytes: max(artifactStorageBytes, 1),
                    accessibilityLabel: "Artifact storage",
                    accessibilityValue: artifactStorageTitle
                )
            }
        }
    }

    private var modelCountTitle: String? {
        guard let installedModelCount = summary.installedModelCount else {
            return nil
        }
        guard let totalModelCount = summary.totalModelCount else {
            return "\(installedModelCount)"
        }
        return "\(installedModelCount)/\(totalModelCount)"
    }

    private var diskFreeTitle: String {
        guard let diskUsage else {
            return artifactStorageTitle
        }
        return "\(byteCountTitle(diskUsage.availableBytes)) free"
    }

    private var diskFreeFraction: Double {
        guard let diskUsage else {
            return 0
        }
        return min(max(Double(diskUsage.availableBytes) / Double(diskUsage.capacityBytes), 0), 1)
    }

    private var diskUsedTitle: String {
        guard let diskUsage else {
            return artifactStorageTitle
        }
        return "\(byteCountTitle(diskUsage.usedBytes)) of \(byteCountTitle(diskUsage.capacityBytes)) used"
    }

    private var storageStatusTitle: String {
        switch diskFreeFraction {
        case ...0.15:
            return "Low space"
        case ..<0.3:
            return "High usage"
        default:
            return "Healthy"
        }
    }

    private var diskTint: Color {
        switch diskFreeFraction {
        case ...0.15:
            return .red
        case ..<0.3:
            return .orange
        default:
            return .green
        }
    }

    private var diskUsage: SettingsDiskUsage? {
        guard
            let availableBytes = summary.availableBytes,
            let capacityBytes = summary.capacityBytes,
            capacityBytes > 0,
            availableBytes >= 0,
            availableBytes <= capacityBytes
        else {
            return nil
        }
        return SettingsDiskUsage(
            availableBytes: availableBytes,
            capacityBytes: capacityBytes,
            usedBytes: capacityBytes - availableBytes
        )
    }

    private var diskChartSegments: [StorageUsageBarSegment] {
        guard let diskUsage else {
            return []
        }
        let artifactBytes = scaledArtifactBytes(toFit: diskUsage.usedBytes)
        let otherUsedBytes = max(diskUsage.usedBytes - artifactBytes.installed - artifactBytes.partial, 0)
        return chartSegments([
            ("Other used", otherUsedBytes, .gray.opacity(0.68)),
            ("Installed", artifactBytes.installed, .blue.opacity(0.9)),
            ("Artifacts", artifactBytes.partial, .orange.opacity(0.9)),
            ("Free", diskUsage.availableBytes, .secondary.opacity(0.18))
        ])
    }

    private var artifactChartSegments: [StorageUsageBarSegment] {
        chartSegments([
            ("Installed", positiveInstalledBytes, .blue.opacity(0.9)),
            ("Artifacts", positivePartialArtifactBytes, .orange.opacity(0.9))
        ])
    }

    private var positiveInstalledBytes: Int64 {
        max(summary.installedModelBytes, 0)
    }

    private var positivePartialArtifactBytes: Int64 {
        max(summary.partialArtifactBytes, 0)
    }

    private var artifactStorageBytes: Int64 {
        positiveInstalledBytes + positivePartialArtifactBytes
    }

    private var artifactStorageTitle: String {
        guard artifactStorageBytes > 0 else {
            return "No artifacts"
        }
        return byteCountTitle(artifactStorageBytes)
    }

    private func scaledArtifactBytes(toFit usedBytes: Int64) -> (installed: Int64, partial: Int64) {
        let artifactBytes = artifactStorageBytes
        guard artifactBytes > usedBytes, artifactBytes > 0 else {
            return (positiveInstalledBytes, positivePartialArtifactBytes)
        }
        let installedFraction = Double(positiveInstalledBytes) / Double(artifactBytes)
        let installed = min(usedBytes, Int64((Double(usedBytes) * installedFraction).rounded()))
        return (installed, max(usedBytes - installed, 0))
    }

    private func chartSegments(_ parts: [(title: String, bytes: Int64, tint: Color)]) -> [StorageUsageBarSegment] {
        parts.compactMap { part in
            let bytes = max(part.bytes, 0)
            guard bytes > 0 else {
                return nil
            }
            return StorageUsageBarSegment(
                title: part.title,
                bytes: bytes,
                tint: part.tint
            )
        }
    }

    private func byteCountTitle(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct SettingsDiskUsage {
    let availableBytes: Int64
    let capacityBytes: Int64
    let usedBytes: Int64
}
