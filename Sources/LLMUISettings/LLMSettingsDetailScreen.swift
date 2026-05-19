import LLMCore
import LLMSettings
import SwiftUI

@MainActor
struct LLMSettingsDetailScreen: View {
    @Binding var settings: LLMRuntimeSettings

    let section: LLMSettingsSection
    let context: LLMSettingsContext
    let configuration: LLMSettingsScreenConfiguration
    let actions: LLMSettingsActions

    @State var showsResetConfirmation = false

    private let normalizer: LLMSettingsNormalizer

    init(
        settings: Binding<LLMRuntimeSettings>,
        section: LLMSettingsSection,
        context: LLMSettingsContext,
        configuration: LLMSettingsScreenConfiguration,
        actions: LLMSettingsActions
    ) {
        self._settings = settings
        self.section = section
        self.context = context
        self.configuration = configuration
        self.actions = actions
        self.normalizer = LLMSettingsNormalizer(constraints: configuration.constraints)
    }

    var body: some View {
        let visual = LLMSettingsSectionVisual(section)

        Form {
            Section {
                LLMSettingsDetailHeader(visual: visual)
            } footer: {
                Text(visual.detail)
            }

            sectionFormSections
        }
        .navigationTitle(visual.title)
        .llmSettingsInlineNavigationTitle()
        .confirmationDialog(
            "Reset AI settings?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Recommended Defaults", role: .destructive) {
                settings.applyPreset(.recommended)
            }
        } message: {
            Text("This resets routing, token limits, local memory, MLX, and GGUF runtime settings.")
        }
    }

    @ViewBuilder
    private var sectionFormSections: some View {
        switch section {
        case .overview:
            EmptyView()
        case .modelAndRouting:
            routingSections
        case .contextAndOutput:
            contextOutputSections
        case .prompt:
            promptSections
        case .localMemory:
            localMemorySections
        case .mlx:
            mlxSections
        case .gguf:
            ggufSections
        case .safety:
            safetySections
        case .storage:
            storageSections
        case .reset:
            resetSections
        }
    }

    var effective: LLMEffectiveSettings {
        normalizer.effectiveSettings(
            for: settings,
            selectedModelContextWindowTokens: context.selectedModelContextWindowTokens,
            isLowMemoryConstrained: context.isLowMemoryConstrained
        )
    }

    var contextRange: ClosedRange<Int> {
        let upper = min(
            configuration.constraints.contextWindowTokens.maximum,
            context.selectedModelContextWindowTokens ?? configuration.constraints.contextWindowTokens.maximum
        )
        let lower = min(configuration.constraints.contextWindowTokens.minimum, upper)
        return lower ... upper
    }

    var outputRange: ClosedRange<Int> {
        configuration.constraints.outputTokens.minimum ... configuration.constraints.outputTokens.maximum
    }

    var localMemoryRange: ClosedRange<Int> {
        configuration.constraints.criticalFreeRAMFloorMB.minimum ... configuration.constraints.criticalFreeRAMFloorMB.maximum
    }

    var mlxCacheRange: ClosedRange<Int> {
        configuration.constraints.mlxCacheLimitMB.minimum ... configuration.constraints.mlxCacheLimitMB.maximum
    }

    var mlxKVRange: ClosedRange<Int> {
        contextRange
    }

    var mlxPrefillRange: ClosedRange<Int> {
        configuration.constraints.mlxPrefillStepSize.minimum ... configuration.constraints.mlxPrefillStepSize.maximum
    }

    var ggufBatchRange: ClosedRange<Int> {
        configuration.constraints.ggufBatchSize.minimum ... configuration.constraints.ggufBatchSize.maximum
    }

    var ggufThreadRange: ClosedRange<Int> {
        configuration.constraints.ggufThreadCount.minimum ... configuration.constraints.ggufThreadCount.maximum
    }

    var ggufGPULayerRange: ClosedRange<Int> {
        configuration.constraints.ggufCustomGPULayers.minimum ... configuration.constraints.ggufCustomGPULayers.maximum
    }

    var executionModes: [ExecutionMode] {
        configuration.showsRemoteRoutingModes
            ? [.offlineOnly, .preferOffline, .hybrid, .remoteAllowed]
            : [.offlineOnly, .preferOffline]
    }

    var ggufAutomaticThreads: Binding<Bool> {
        Binding(
            get: { settings.ggufThreadCount == nil },
            set: { isAutomatic in
                settings.ggufThreadCount = isAutomatic ? nil : configuration.constraints.ggufThreadCount.minimum
            }
        )
    }

    var ggufThreadCount: Binding<Int> {
        Binding(
            get: { settings.ggufThreadCount ?? configuration.constraints.ggufThreadCount.minimum },
            set: { settings.ggufThreadCount = $0 }
        )
    }

    var ggufCustomGPULayers: Binding<Int> {
        Binding(
            get: { settings.ggufGPUOffloadPolicy.requestedLayerCount },
            set: { settings.ggufGPUOffloadPolicy = .custom(layerCount: $0) }
        )
    }

    static let qualityTiers: [QualityTier] = [.fast, .balanced, .best]
    static let privacyModes: [PrivacyMode] = [.standard, .localOnly, .redactSensitive]
}

extension View {
    @ViewBuilder
    func llmSettingsInlineNavigationTitle() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
