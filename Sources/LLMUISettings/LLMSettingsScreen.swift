import LLMCore
import LLMSettings
import SwiftUI

@MainActor
public struct LLMSettingsScreen: View {
    @Binding private var settings: LLMRuntimeSettings

    private let context: LLMSettingsContext
    private let configuration: LLMSettingsScreenConfiguration
    private let actions: LLMSettingsActions
    private let normalizer: LLMSettingsNormalizer

    public init(
        settings: Binding<LLMRuntimeSettings>,
        context: LLMSettingsContext = LLMSettingsContext(),
        configuration: LLMSettingsScreenConfiguration = LLMSettingsScreenConfiguration(),
        actions: LLMSettingsActions = LLMSettingsActions()
    ) {
        self._settings = settings
        self.context = context
        self.configuration = configuration
        self.actions = actions
        self.normalizer = LLMSettingsNormalizer(constraints: configuration.constraints)
    }

    public var body: some View {
        Form {
            if shows(.overview) {
                overviewSection
            }
            if !navigableSections.isEmpty {
                settingsGroupsSection
            }
        }
        .navigationTitle(configuration.title)
        .onChange(of: settings) { _, newValue in
            normalize(newValue, shouldNotify: true)
        }
        .task {
            normalize(settings, shouldNotify: false)
        }
    }

    private var overviewSection: some View {
        Section {
            LLMSettingsOverviewContent(
                selectedModelName: context.selectedModelName,
                metadata: overviewMetadata,
                effectiveInputTokens: effective.inputTokens,
                effectiveOutputTokens: effective.outputTokens,
                isLowMemoryConstrained: context.isLowMemoryConstrained,
                recommendation: context.recommendation
            )
        } header: {
            Text("Overview")
        }
    }

    private var settingsGroupsSection: some View {
        Section {
            ForEach(navigableSections, id: \.self) { section in
                NavigationLink {
                    LLMSettingsDetailScreen(
                        settings: $settings,
                        section: section,
                        context: context,
                        configuration: configuration,
                        actions: actions
                    )
                } label: {
                    let visual = LLMSettingsSectionVisual(section)
                    LLMSettingsNavigationRow(
                        title: visual.title,
                        subtitle: visual.subtitle,
                        value: summaryValue(for: section),
                        systemImage: visual.systemImage,
                        tint: visual.tint
                    )
                }
            }
        } header: {
            Text("Settings Groups")
        } footer: {
            Text("Open a group to tune related runtime values. Lower context, KV, or cache limits first when memory is tight.")
        }
    }

    private var navigableSections: [LLMSettingsSection] {
        LLMSettingsSection.allCases.filter { section in
            section != .overview && shows(section)
        }
    }

    private var effective: LLMEffectiveSettings {
        normalizer.effectiveSettings(
            for: settings,
            selectedModelContextWindowTokens: context.selectedModelContextWindowTokens,
            isLowMemoryConstrained: context.isLowMemoryConstrained
        )
    }

    private var overviewMetadata: String? {
        let parts = [context.selectedModelBackendTitle, context.selectedModelStatus]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    private func shows(_ section: LLMSettingsSection) -> Bool {
        configuration.visibleSections.contains(section)
    }

    private func normalize(_ candidate: LLMRuntimeSettings, shouldNotify: Bool) {
        let normalized = normalizer.normalized(
            candidate,
            selectedModelContextWindowTokens: context.selectedModelContextWindowTokens
        )
        if normalized != settings {
            settings = normalized
        } else if shouldNotify {
            actions.onSettingsChanged?(normalized)
        }
    }

    private func summaryValue(for section: LLMSettingsSection) -> String? {
        switch section {
        case .overview:
            return nil
        case .modelAndRouting:
            return LLMSettingsFormatting.title(for: settings.executionMode)
        case .contextAndOutput:
            return "\(LLMSettingsFormatting.tokenCount(effective.inputTokens)) / \(LLMSettingsFormatting.tokenCount(effective.outputTokens))"
        case .prompt:
            return context.promptSummary == nil ? "Host-owned" : nil
        case .localMemory:
            return LLMSettingsFormatting.megabytes(settings.criticalFreeRAMFloorMB)
        case .mlx:
            return "\(LLMSettingsFormatting.megabytes(settings.mlxCacheLimitMB)), KV \(LLMSettingsFormatting.tokenCount(effective.mlxKVSizeTokens))"
        case .gguf:
            return LLMSettingsFormatting.tokenCount(effective.ggufContextSizeTokens)
        case .safety:
            return "Host-owned"
        case .storage:
            return context.catalogSourceTitle
        case .reset:
            return "Recommended"
        }
    }
}
