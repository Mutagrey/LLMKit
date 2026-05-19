import Foundation
import LLMSettings
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

            if context.catalogSourceTitle != nil || context.catalogMessage != nil {
                Section {
                    if let catalogSourceTitle = context.catalogSourceTitle {
                        LabeledContent("Catalog", value: catalogSourceTitle)
                    }
                    if let catalogMessage = context.catalogMessage {
                        Text(catalogMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if hasStorageCleanupActions {
                Section {
                    if let clearModelArtifacts = actions.clearModelArtifacts {
                        Button(role: .destructive) {
                            Task { await clearModelArtifacts() }
                        } label: {
                            Label("Clear artifacts", systemImage: "shippingbox")
                        }
                    }

                    if let clearChatSessions = actions.clearChatSessions {
                        Button(role: .destructive) {
                            Task { await clearChatSessions() }
                        } label: {
                            Label("Clear chats", systemImage: "bubble.left.and.bubble.right")
                        }
                    }

                    if let clearInstalledModels = actions.clearInstalledModels {
                        Button(role: .destructive) {
                            Task { await clearInstalledModels() }
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

private struct LLMSettingsStorageUsageView: View {
    let summary: LLMSettingsStorageSummary

    private let columns = [
        GridItem(.adaptive(minimum: 94), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                if let modelCountTitle {
                    metric(value: modelCountTitle, label: "Models", tint: .green)
                }
                if let chatCount = summary.chatCount {
                    metric(value: "\(chatCount)", label: "Chats", tint: .cyan)
                }
                metric(value: byteCountTitle(summary.installedModelBytes), label: "Installed", tint: .blue)
                metric(value: byteCountTitle(summary.partialArtifactBytes), label: "Artifacts", tint: .orange)
            }

            if let diskTitle {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(diskTitle)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(diskPercentTitle)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(diskTint)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                            Capsule(style: .continuous)
                                .fill(diskTint.opacity(0.8))
                                .frame(width: max(geometry.size.width * diskUsedFraction, 4))
                        }
                    }
                    .frame(height: 5)
                    .clipShape(Capsule(style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
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

    private var diskTitle: String? {
        guard let availableBytes = summary.availableBytes, let capacityBytes = summary.capacityBytes, capacityBytes > 0 else {
            return nil
        }
        return "\(byteCountTitle(availableBytes)) free of \(byteCountTitle(capacityBytes))"
    }

    private var diskUsedFraction: Double {
        guard let availableBytes = summary.availableBytes, let capacityBytes = summary.capacityBytes, capacityBytes > 0 else {
            return 0
        }
        return min(max(Double(capacityBytes - availableBytes) / Double(capacityBytes), 0), 1)
    }

    private var diskPercentTitle: String {
        "\(Int((diskUsedFraction * 100).rounded()))%"
    }

    private var diskTint: Color {
        switch diskUsedFraction {
        case 0.85...:
            return .red
        case 0.7..<0.85:
            return .orange
        default:
            return .green
        }
    }

    private func byteCountTitle(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
