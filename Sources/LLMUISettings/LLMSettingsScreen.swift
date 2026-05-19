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

    @State private var showsResetConfirmation = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if shows(.overview) {
                    overviewCard
                }

                settingsGroups
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .navigationTitle(configuration.title)
        .onChange(of: settings) { _, newValue in
            normalize(newValue, shouldNotify: true)
        }
        .task {
            normalize(settings, shouldNotify: false)
        }
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

    private var overviewCard: some View {
        LLMSettingsChromeCard {
            HStack(alignment: .top, spacing: 12) {
                LLMSettingsChromeIcon(systemImage: "sparkles", tint: .blue)

                VStack(alignment: .leading, spacing: 6) {
                    Text(context.selectedModelName ?? "No model selected")
                        .font(.headline)
                        .lineLimit(2)

                    Text("Effective runtime profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            if context.selectedModelBackendTitle != nil || context.selectedModelStatus != nil {
                HStack(spacing: 8) {
                    if let backend = context.selectedModelBackendTitle {
                        LLMSettingsBadge(text: backend, tint: .blue)
                    }
                    if let status = context.selectedModelStatus {
                        LLMSettingsBadge(text: status, tint: .green)
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                overviewMetric(
                    title: "Effective context",
                    value: LLMSettingsFormatting.tokenCount(effective.inputTokens),
                    caption: "Prompt and history budget"
                )

                overviewMetric(
                    title: "Max answer",
                    value: LLMSettingsFormatting.tokenCount(effective.outputTokens),
                    caption: "Generation cap"
                )
            }

            if context.isLowMemoryConstrained {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Low memory mode is limiting context and output.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let recommendation = context.recommendation {
                Text(recommendation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsGroups: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings Groups")
                .font(.headline)

            LLMSettingsChromeCard(spacing: 14) {
                ForEach(navigableSections, id: \.self) { section in
                    NavigationLink {
                        sectionDestination(for: section)
                    } label: {
                        let visual = visual(for: section)
                        LLMSettingsNavigationRow(
                            title: visual.title,
                            subtitle: visual.subtitle,
                            value: summaryValue(for: section),
                            systemImage: visual.systemImage,
                            tint: visual.tint
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Open a group to tune related runtime values. Defaults are local-first and safe for normal use; lower context, KV, or cache limits first when memory is tight.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func overviewMetric(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionDestination(for section: LLMSettingsSection) -> some View {
        let visual = visual(for: section)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LLMSettingsDetailHeader(visual: visual)

                LLMSettingsChromeCard {
                    sectionControls(for: section)
                }

                Text(visual.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .navigationTitle(visual.title)
        .llmSettingsInlineNavigationTitle()
    }

    @ViewBuilder
    private func sectionControls(for section: LLMSettingsSection) -> some View {
        switch section {
        case .overview:
            EmptyView()
        case .modelAndRouting:
            modelAndRoutingControls
        case .contextAndOutput:
            contextAndOutputControls
        case .prompt:
            promptControls
        case .localMemory:
            localMemoryControls
        case .mlx:
            mlxControls
        case .gguf:
            ggufControls
        case .safety:
            safetyControls
        case .storage:
            storageControls
        case .reset:
            resetControls
        }
    }

    private var modelAndRoutingControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let openModelSettings = actions.openModelSettings {
                Button {
                    openModelSettings()
                } label: {
                    Label("Choose or manage models", systemImage: "cpu")
                }
            }

            if configuration.allowsRoutingControls {
                Picker("Execution", selection: $settings.executionMode) {
                    ForEach(executionModes, id: \.self) { mode in
                        Text(LLMSettingsFormatting.title(for: mode)).tag(mode)
                    }
                }
                LLMSettingHint("Controls which backends can be considered before generation starts.")

                Picker("Quality", selection: $settings.qualityTier) {
                    ForEach(Self.qualityTiers, id: \.self) { tier in
                        Text(LLMSettingsFormatting.title(for: tier)).tag(tier)
                    }
                }

                Picker("Privacy", selection: $settings.privacyMode) {
                    ForEach(Self.privacyModes, id: \.self) { mode in
                        Text(LLMSettingsFormatting.title(for: mode)).tag(mode)
                    }
                }
                LLMSettingHint("Privacy mode limits whether non-local execution can be used by the host app.")
            } else {
                LabeledContent("Execution", value: LLMSettingsFormatting.title(for: settings.executionMode))
                LabeledContent("Privacy", value: LLMSettingsFormatting.title(for: settings.privacyMode))
                LLMSettingHint("This profile is controlled by the host app and kept local/offline.")
            }

            Button("Reset routing defaults") {
                settings.resetRouting()
            }
        }
    }

    private var contextAndOutputControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper(value: $settings.contextWindowTokens, in: contextRange, step: configuration.constraints.contextWindowTokens.step) {
                LabeledContent("Context window") {
                    Text(LLMSettingsFormatting.tokenCount(effective.inputTokens))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            LLMSettingHint("Raises or lowers the prompt and recent-history budget. Larger windows use more memory.")

            Stepper(value: $settings.maxOutputTokens, in: outputRange, step: configuration.constraints.outputTokens.step) {
                LabeledContent("Max output") {
                    Text(LLMSettingsFormatting.tokenCount(effective.outputTokens))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            LLMSettingHint("Caps answer length. Higher values can improve long responses but increase latency.")

            Button("Reset token defaults") {
                settings.resetGeneration()
            }
        }
    }

    private var promptControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(context.promptSummary ?? "Prompt content is owned by the host app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let resetPrompt = actions.resetPrompt {
                Button("Reset prompt default") {
                    resetPrompt()
                }
            }
        }
    }

    private var localMemoryControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper(
                value: $settings.criticalFreeRAMFloorMB,
                in: localMemoryRange,
                step: configuration.constraints.criticalFreeRAMFloorMB.step
            ) {
                LabeledContent("Free RAM floor") {
                    Text(LLMSettingsFormatting.megabytes(settings.criticalFreeRAMFloorMB))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            LLMSettingHint("Blocks local starts when free memory drops below this value. Raise it for stability.")

            Button("Reset memory defaults") {
                settings.resetMemory()
            }
        }
    }

    private var mlxControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper(value: $settings.mlxCacheLimitMB, in: mlxCacheRange, step: configuration.constraints.mlxCacheLimitMB.step) {
                LabeledContent("MLX cache limit") {
                    Text(LLMSettingsFormatting.megabytes(settings.mlxCacheLimitMB))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $settings.mlxMaxKVSizeTokens, in: mlxKVRange, step: configuration.constraints.mlxMaxKVSizeTokens.step) {
                LabeledContent("KV cache window") {
                    Text(LLMSettingsFormatting.tokenCount(effective.mlxKVSizeTokens))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Picker("KV quantization", selection: $settings.mlxKVBits) {
                Text("Off").tag(0)
                Text("4-bit").tag(4)
                Text("8-bit").tag(8)
            }

            Stepper(value: $settings.mlxPrefillStepSize, in: mlxPrefillRange, step: configuration.constraints.mlxPrefillStepSize.step) {
                LabeledContent("Prefill step") {
                    Text(LLMSettingsFormatting.tokenCount(settings.mlxPrefillStepSize))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Retain chat sessions", isOn: $settings.mlxRetainChatSessions)

            if configuration.showsAdvancedRuntimeControls {
                Toggle("Clear cache after generation", isOn: $settings.mlxClearCacheAfterGeneration)
                Toggle("Clear cache on unload", isOn: $settings.mlxClearCacheOnUnload)
            }

            LLMSettingHint("Cache and KV settings trade memory for speed. Quantized KV is usually the first knob to use on constrained devices.")

            Button("Reset MLX defaults") {
                settings.resetMLX()
            }
        }
    }

    private var ggufControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Follow context window", isOn: $settings.ggufContextFollowsRequest)

            if !settings.ggufContextFollowsRequest {
                Stepper(value: $settings.ggufContextWindowTokens, in: contextRange, step: configuration.constraints.contextWindowTokens.step) {
                    LabeledContent("GGUF context") {
                        Text(LLMSettingsFormatting.tokenCount(effective.ggufContextSizeTokens))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Toggle("Use mmap", isOn: $settings.ggufUseMMap)

            Picker("GPU offload", selection: $settings.ggufGPUOffloadPolicy) {
                Text("Automatic").tag(LLMGPUOffloadPolicy.automatic)
                Text("Off").tag(LLMGPUOffloadPolicy.disabled)
                Text("Custom").tag(LLMGPUOffloadPolicy.custom(layerCount: settings.ggufGPUOffloadPolicy.requestedLayerCount))
            }

            if case .custom = settings.ggufGPUOffloadPolicy {
                Stepper(value: ggufCustomGPULayers, in: ggufGPULayerRange, step: configuration.constraints.ggufCustomGPULayers.step) {
                    LabeledContent("GPU layers") {
                        Text("\(settings.ggufGPUOffloadPolicy.requestedLayerCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Picker("KV cache", selection: $settings.ggufKVCachePolicy) {
                Text("Runtime Default").tag(KVCachePolicy.runtimeDefault)
                Text("Safe F16").tag(KVCachePolicy.safeF16)
                Text("Q8 Experimental").tag(KVCachePolicy.q8Experimental)
                Text("Q4 Experimental").tag(KVCachePolicy.q4Experimental)
            }

            Stepper(value: $settings.ggufBatchSize, in: ggufBatchRange, step: configuration.constraints.ggufBatchSize.step) {
                LabeledContent("Batch size") {
                    Text("\(settings.ggufBatchSize)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Automatic threads", isOn: ggufAutomaticThreads)

            if settings.ggufThreadCount != nil {
                Stepper(value: ggufThreadCount, in: ggufThreadRange, step: configuration.constraints.ggufThreadCount.step) {
                    LabeledContent("Threads") {
                        Text("\(settings.ggufThreadCount ?? 0)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            LLMSettingHint("These values affect native llama.cpp memory use. Context, batch, and GPU offload can require unloading active GGUF contexts.")

            Button("Reset GGUF defaults") {
                settings.resetGGUF()
            }
        }
    }

    private var safetyControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(context.safetySummary ?? "Safety policy is owned by the host app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var storageControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(context.storageRows) { row in
                VStack(alignment: .leading, spacing: 3) {
                    LabeledContent(row.title, value: row.value)
                    if let detail = row.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let catalogSourceTitle = context.catalogSourceTitle {
                LabeledContent("Catalog", value: catalogSourceTitle)
            }

            if let catalogMessage = context.catalogMessage {
                Text(catalogMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let openSessionSettings = actions.openSessionSettings {
                Button {
                    openSessionSettings()
                } label: {
                    Label("Manage chat sessions", systemImage: "bubble.left.and.bubble.right")
                }
            }
        }
    }

    private var resetControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Menu {
                ForEach(LLMSettingsPreset.allCases, id: \.self) { preset in
                    Button(LLMSettingsFormatting.title(for: preset)) {
                        settings.applyPreset(preset)
                    }
                }
            } label: {
                Label("Apply preset", systemImage: "slider.horizontal.3")
            }

            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label("Reset AI settings to recommended defaults", systemImage: "arrow.counterclockwise")
            }

            LLMSettingHint("Section resets keep other groups unchanged. Full reset restores recommended local-first defaults.")
        }
    }

    private static let qualityTiers: [QualityTier] = [.fast, .balanced, .best]
    private static let privacyModes: [PrivacyMode] = [.standard, .localOnly, .redactSensitive]

    private var navigableSections: [LLMSettingsSection] {
        LLMSettingsSection.allCases.filter { section in
            section != .overview && shows(section)
        }
    }

    private var executionModes: [ExecutionMode] {
        configuration.showsRemoteRoutingModes
            ? [.offlineOnly, .preferOffline, .hybrid, .remoteAllowed]
            : [.offlineOnly, .preferOffline]
    }

    private var effective: LLMEffectiveSettings {
        normalizer.effectiveSettings(
            for: settings,
            selectedModelContextWindowTokens: context.selectedModelContextWindowTokens,
            isLowMemoryConstrained: context.isLowMemoryConstrained
        )
    }

    private var contextRange: ClosedRange<Int> {
        let upper = min(
            configuration.constraints.contextWindowTokens.maximum,
            context.selectedModelContextWindowTokens ?? configuration.constraints.contextWindowTokens.maximum
        )
        let lower = min(configuration.constraints.contextWindowTokens.minimum, upper)
        return lower ... upper
    }

    private var outputRange: ClosedRange<Int> {
        configuration.constraints.outputTokens.minimum ... configuration.constraints.outputTokens.maximum
    }

    private var localMemoryRange: ClosedRange<Int> {
        configuration.constraints.criticalFreeRAMFloorMB.minimum ... configuration.constraints.criticalFreeRAMFloorMB.maximum
    }

    private var mlxCacheRange: ClosedRange<Int> {
        configuration.constraints.mlxCacheLimitMB.minimum ... configuration.constraints.mlxCacheLimitMB.maximum
    }

    private var mlxKVRange: ClosedRange<Int> {
        contextRange
    }

    private var mlxPrefillRange: ClosedRange<Int> {
        configuration.constraints.mlxPrefillStepSize.minimum ... configuration.constraints.mlxPrefillStepSize.maximum
    }

    private var ggufBatchRange: ClosedRange<Int> {
        configuration.constraints.ggufBatchSize.minimum ... configuration.constraints.ggufBatchSize.maximum
    }

    private var ggufThreadRange: ClosedRange<Int> {
        configuration.constraints.ggufThreadCount.minimum ... configuration.constraints.ggufThreadCount.maximum
    }

    private var ggufGPULayerRange: ClosedRange<Int> {
        configuration.constraints.ggufCustomGPULayers.minimum ... configuration.constraints.ggufCustomGPULayers.maximum
    }

    private var ggufAutomaticThreads: Binding<Bool> {
        Binding(
            get: { settings.ggufThreadCount == nil },
            set: { isAutomatic in
                settings.ggufThreadCount = isAutomatic ? nil : configuration.constraints.ggufThreadCount.minimum
            }
        )
    }

    private var ggufThreadCount: Binding<Int> {
        Binding(
            get: { settings.ggufThreadCount ?? configuration.constraints.ggufThreadCount.minimum },
            set: { settings.ggufThreadCount = $0 }
        )
    }

    private var ggufCustomGPULayers: Binding<Int> {
        Binding(
            get: { settings.ggufGPUOffloadPolicy.requestedLayerCount },
            set: { settings.ggufGPUOffloadPolicy = .custom(layerCount: $0) }
        )
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

    private func visual(for section: LLMSettingsSection) -> LLMSettingsSectionVisual {
        switch section {
        case .overview:
            return LLMSettingsSectionVisual(
                title: "Overview",
                subtitle: "Current model, effective limits, and recommendations",
                detail: "Effective values include user settings, selected model limits, and memory clamps.",
                systemImage: "sparkles",
                tint: .blue
            )
        case .modelAndRouting:
            return LLMSettingsSectionVisual(
                title: "Model & Routing",
                subtitle: "Backend selection, quality profile, and privacy mode",
                detail: "Routing controls decide which backends can be considered. Privacy mode affects whether non-local execution is allowed.",
                systemImage: "point.3.connected.trianglepath.dotted",
                tint: .blue
            )
        case .contextAndOutput:
            return LLMSettingsSectionVisual(
                title: "Context & Output",
                subtitle: "Input window, answer length, and model caps",
                detail: "Context is the input budget for prompts and recent chat history. Max output is the answer budget; higher values use more memory and time.",
                systemImage: "text.word.spacing",
                tint: .purple
            )
        case .prompt:
            return LLMSettingsSectionVisual(
                title: "Prompt",
                subtitle: "Host-owned system prompt and behavior summary",
                detail: "System prompts define assistant behavior. Keep safety and domain constraints here instead of duplicating them in backend code.",
                systemImage: "text.alignleft",
                tint: .indigo
            )
        case .localMemory:
            return LLMSettingsSectionVisual(
                title: "Local Memory",
                subtitle: "Free RAM floor and low-memory behavior",
                detail: "The RAM floor blocks local starts when memory is tight. Raise it for stability; lower it only for controlled experiments.",
                systemImage: "memorychip",
                tint: .orange
            )
        case .mlx:
            return LLMSettingsSectionVisual(
                title: "MLX",
                subtitle: "Cache, KV window, quantization, and prefill",
                detail: "MLX cache and KV controls trade memory for speed. Quantized KV reduces memory; larger prefill steps may improve speed but can spike RAM.",
                systemImage: "bolt.horizontal",
                tint: .yellow
            )
        case .gguf:
            return LLMSettingsSectionVisual(
                title: "GGUF",
                subtitle: "llama.cpp context, mmap, GPU, batch, and threads",
                detail: "GGUF context controls native llama.cpp memory. mmap lowers load pressure, Metal speeds supported devices, and experimental KV policies may fall back at runtime.",
                systemImage: "cpu",
                tint: .teal
            )
        case .safety:
            return LLMSettingsSectionVisual(
                title: "Safety",
                subtitle: "Host-owned boundaries and fallback behavior",
                detail: "Safety settings should describe boundaries and failure behavior without leaking backend-specific implementation.",
                systemImage: "shield",
                tint: .red
            )
        case .storage:
            return LLMSettingsSectionVisual(
                title: "Storage",
                subtitle: "Model files, catalog status, and saved sessions",
                detail: "Model files, partial downloads, and saved sessions affect disk use but stay separate from inference routing.",
                systemImage: "internaldrive",
                tint: .cyan
            )
        case .reset:
            return LLMSettingsSectionVisual(
                title: "Reset",
                subtitle: "Presets, per-section resets, and recommended defaults",
                detail: "Use presets for broad tuning. Full reset restores the recommended defaults after confirmation.",
                systemImage: "arrow.counterclockwise",
                tint: .gray
            )
        }
    }
}

private struct LLMSettingsSectionVisual {
    let title: String
    let subtitle: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private struct LLMSettingsDetailHeader: View {
    let visual: LLMSettingsSectionVisual

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LLMSettingsChromeIcon(systemImage: visual.systemImage, tint: visual.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(visual.title)
                    .font(.title3.weight(.semibold))

                Text(visual.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct LLMSettingHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    @ViewBuilder
    func llmSettingsInlineNavigationTitle() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
