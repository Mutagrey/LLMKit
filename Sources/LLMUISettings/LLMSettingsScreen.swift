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
        Form {
            if shows(.overview) {
                overviewSection
            }
            if shows(.modelAndRouting) {
                modelAndRoutingSection
            }
            if shows(.contextAndOutput) {
                contextAndOutputSection
            }
            if shows(.prompt) {
                promptSection
            }
            if shows(.localMemory) {
                localMemorySection
            }
            if shows(.mlx) {
                mlxSection
            }
            if shows(.gguf) {
                ggufSection
            }
            if shows(.safety) {
                safetySection
            }
            if shows(.storage) {
                storageSection
            }
            if shows(.reset) {
                resetSection
            }
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

    private var overviewSection: some View {
        Section {
            if let selectedModelName = context.selectedModelName {
                LabeledContent("Selected model", value: selectedModelName)
            } else {
                Text("No model selected")
                    .foregroundStyle(.secondary)
            }
            if let backend = context.selectedModelBackendTitle {
                LabeledContent("Backend", value: backend)
            }
            if let status = context.selectedModelStatus {
                LabeledContent("Status", value: status)
            }
            LabeledContent("Effective context", value: LLMSettingsFormatting.tokenCount(effective.inputTokens))
            LabeledContent("Max answer", value: LLMSettingsFormatting.tokenCount(effective.outputTokens))
            if context.isLowMemoryConstrained {
                Label("Low memory mode is limiting context and output.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let recommendation = context.recommendation {
                Text(recommendation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Overview")
        } footer: {
            Text("Effective values are the settings after model limits and memory clamps are applied.")
        }
    }

    private var modelAndRoutingSection: some View {
        Section {
            if let openModelSettings = actions.openModelSettings {
                Button("Choose or manage models") {
                    openModelSettings()
                }
            }
            if configuration.allowsRoutingControls {
                Picker("Execution", selection: $settings.executionMode) {
                    ForEach(executionModes, id: \.self) { mode in
                        Text(LLMSettingsFormatting.title(for: mode)).tag(mode)
                    }
                }
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
            } else {
                LabeledContent("Execution", value: LLMSettingsFormatting.title(for: settings.executionMode))
                LabeledContent("Privacy", value: LLMSettingsFormatting.title(for: settings.privacyMode))
            }
            Button("Reset routing defaults") {
                settings.resetRouting()
            }
        } header: {
            Text("Model & Routing")
        } footer: {
            Text("Routing controls decide which backends can be considered. Privacy mode affects whether non-local execution is allowed.")
        }
    }

    private var contextAndOutputSection: some View {
        Section {
            Stepper(value: $settings.contextWindowTokens, in: contextRange, step: configuration.constraints.contextWindowTokens.step) {
                LabeledContent("Context window") {
                    Text(LLMSettingsFormatting.tokenCount(effective.inputTokens))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: $settings.maxOutputTokens, in: outputRange, step: configuration.constraints.outputTokens.step) {
                LabeledContent("Max output") {
                    Text(LLMSettingsFormatting.tokenCount(effective.outputTokens))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Button("Reset token defaults") {
                settings.resetGeneration()
            }
        } header: {
            Text("Context & Output")
        } footer: {
            Text("Context is the input budget for prompts and recent chat history. Max output is the answer budget; higher values use more memory and time.")
        }
    }

    private var promptSection: some View {
        Section {
            Text(context.promptSummary ?? "Prompt content is owned by the host app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let resetPrompt = actions.resetPrompt {
                Button("Reset prompt default") {
                    resetPrompt()
                }
            }
        } header: {
            Text("Prompt")
        } footer: {
            Text("System prompts define assistant behavior. Keep safety and domain constraints here instead of duplicating them in backend code.")
        }
    }

    private var localMemorySection: some View {
        Section {
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
            Button("Reset memory defaults") {
                settings.resetMemory()
            }
        } header: {
            Text("Local Memory")
        } footer: {
            Text("The RAM floor blocks local starts when memory is tight. Raise it for stability; lower it only for controlled experiments.")
        }
    }

    private var mlxSection: some View {
        Section {
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
            Button("Reset MLX defaults") {
                settings.resetMLX()
            }
        } header: {
            Text("MLX")
        } footer: {
            Text("MLX cache and KV controls trade memory for speed. Quantized KV reduces memory; larger prefill steps may improve speed but can spike RAM.")
        }
    }

    private var ggufSection: some View {
        Section {
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
            Button("Reset GGUF defaults") {
                settings.resetGGUF()
            }
        } header: {
            Text("GGUF")
        } footer: {
            Text("GGUF context controls native llama.cpp memory. mmap lowers load pressure, Metal speeds supported devices, and experimental KV policies may fall back at runtime.")
        }
    }

    private var safetySection: some View {
        Section {
            Text(context.safetySummary ?? "Safety policy is owned by the host app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Safety")
        } footer: {
            Text("Safety settings should describe boundaries and failure behavior without leaking backend-specific implementation.")
        }
    }

    private var storageSection: some View {
        Section {
            ForEach(context.storageRows) { row in
                LabeledContent(row.title, value: row.value)
                if let detail = row.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let catalogSourceTitle = context.catalogSourceTitle {
                LabeledContent("Catalog", value: catalogSourceTitle)
            }
            if let catalogMessage = context.catalogMessage {
                Text(catalogMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let openSessionSettings = actions.openSessionSettings {
                Button("Manage chat sessions") {
                    openSessionSettings()
                }
            }
        } header: {
            Text("Storage")
        } footer: {
            Text("Model files, partial downloads, and saved sessions affect disk use but stay separate from inference routing.")
        }
    }

    private var resetSection: some View {
        Section {
            Menu("Apply preset") {
                ForEach(LLMSettingsPreset.allCases, id: \.self) { preset in
                    Button(LLMSettingsFormatting.title(for: preset)) {
                        settings.applyPreset(preset)
                    }
                }
            }
            Button("Reset AI settings to recommended defaults", role: .destructive) {
                showsResetConfirmation = true
            }
        } header: {
            Text("Reset")
        } footer: {
            Text("Section resets keep other groups unchanged. Full reset restores the recommended local-first defaults.")
        }
    }

    private static let qualityTiers: [QualityTier] = [.fast, .balanced, .best]
    private static let privacyModes: [PrivacyMode] = [.standard, .localOnly, .redactSensitive]

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
}
