import LLMCore
import LLMSettings
import LLMUIModels
import LLMUISettings
import SwiftUI

struct SettingsTab: View {
    let viewModel: DemoViewModel

    var body: some View {
        NavigationStack {
            LLMSettingsScreen(
                settings: settings,
                context: settingsContext,
                configuration: LLMSettingsScreenConfiguration(title: "Settings")
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
            selectedModelStatus: viewModel.selectedModel.map { viewModel.statusText(for: $0) },
            selectedModelContextWindowTokens: viewModel.selectedModel?.contextWindowTokens,
            catalogSourceTitle: catalogSourceTitle,
            catalogMessage: catalogMessage,
            promptSummary: "Prompt skills are configured in the Skills tab and sent as transient system context for each chat.",
            safetySummary: "The demo keeps safety policy backend-neutral. App-specific products should add their own domain boundaries.",
            recommendation: "Use recommended defaults for normal local chat. Lower context, KV, and cache values on memory-constrained devices."
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
}
