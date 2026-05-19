import LLMSettings
import SwiftUI

@MainActor
extension LLMSettingsDetailScreen {
    var storageSections: some View {
        Group {
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
