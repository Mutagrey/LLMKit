import LLMCore
import LLMSettings
import LLMUIModels
import LLMUISettings
import SwiftUI

struct SettingsTab: View {
    let viewModel: DemoViewModel
    let downloadsViewModel: ModelDownloadsViewModel
    let skillStore: DemoPromptSkillStore

    var body: some View {
        NavigationStack {
            LLMSettingsScreen(
                settings: settings,
                context: settingsContext,
                configuration: LLMSettingsScreenConfiguration(title: "Settings"),
                actions: settingsActions
            )
        }
    }

    private var settings: Binding<LLMRuntimeSettings> {
        Binding(
            get: { viewModel.settings },
            set: { newValue in
                var updated = newValue
                updated.preferredModelID = updated.preferredModelID ?? viewModel.selectedModelID
                viewModel.settings = updated
            }
        )
    }

    private var settingsContext: LLMSettingsContext {
        LLMSettingsContext(
            selectedModelName: viewModel.selectedModel?.displayName,
            selectedModelBackendTitle: viewModel.selectedModel.map { ModelFormatting.backendTitle($0.backend) },
            selectedModelStatus: viewModel.selectedModel.map(statusText(for:)),
            selectedModelContextWindowTokens: viewModel.selectedModel?.contextWindowTokens,
            catalogSourceTitle: catalogSourceTitle,
            catalogMessage: catalogMessage,
            promptSummary: "Prompt skills are configured in the Skills tab and sent as transient system context for each chat.",
            safetySummary: "The demo keeps safety policy backend-neutral. App-specific products should add their own domain boundaries.",
            storageSummary: storageSummary,
            recommendation: "Use recommended defaults for normal local chat. Lower context, KV, and cache values on memory-constrained devices."
        )
    }

    private var settingsActions: LLMSettingsActions {
        LLMSettingsActions(
            clearModelArtifacts: {
                await downloadsViewModel.refresh()
                await downloadsViewModel.clearPartialArtifacts()
                await refreshStorageState()
            },
            clearChatSessions: {
                await clearChatSessions()
            },
            clearInstalledModels: {
                await downloadsViewModel.refresh()
                await downloadsViewModel.clearInstalledModels()
                await refreshStorageState()
            }
        )
    }

    private var storageSummary: LLMSettingsStorageSummary {
        LLMSettingsStorageSummary(
            installedModelCount: viewModel.downloadableModels.filter { downloadsViewModel.isInstalled($0.id) }.count,
            totalModelCount: viewModel.models.count,
            chatCount: viewModel.sessions.count,
            installedModelBytes: downloadsViewModel.installedStorageBytes,
            partialArtifactBytes: downloadsViewModel.partialStorageBytes,
            availableBytes: downloadsViewModel.storageUsage.availableBytes,
            capacityBytes: downloadsViewModel.storageUsage.capacityBytes
        )
    }

    private var catalogSourceTitle: String {
        switch viewModel.catalogStatus.source {
        case .local:
            return "Local"
        case .remoteVerified:
            return "Signed Remote"
        case .fallback:
            return "Fallback"
        }
    }

    private var catalogMessage: String? {
        guard let message = viewModel.catalogStatus.message, !message.isEmpty else {
            return nil
        }
        return message
    }

    private func statusText(for descriptor: ModelDescriptor) -> String {
        if viewModel.downloadableModels.contains(where: { $0.id == descriptor.id }) {
            return downloadsViewModel.statusText(for: descriptor.id)
        }
        return viewModel.statusText(for: descriptor)
    }

    @MainActor
    private func clearChatSessions() async {
        let sessionIDs = viewModel.sessions.map(\.id)
        do {
            try await viewModel.deleteAllSessions()
            sessionIDs.forEach { skillStore.removeSelection(for: $0) }
        } catch {
            viewModel.setLastErrorMessage(String(describing: error))
        }
    }

    @MainActor
    private func refreshStorageState() async {
        await viewModel.refresh()
        await downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }
}
