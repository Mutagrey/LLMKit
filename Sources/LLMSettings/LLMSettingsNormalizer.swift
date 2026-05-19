import Foundation
import LLMCore

public struct LLMSettingsNormalizer: Sendable {
    public let constraints: LLMSettingsConstraints

    public init(constraints: LLMSettingsConstraints = .recommended) {
        self.constraints = constraints
    }

    public func normalized(
        _ settings: LLMRuntimeSettings,
        selectedModelContextWindowTokens: Int? = nil
    ) -> LLMRuntimeSettings {
        var normalized = settings
        normalized.contextWindowTokens = contextWindowTokenLimit(
            settings.contextWindowTokens,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens
        )
        normalized.maxOutputTokens = constraints.outputTokens.roundedToStep(settings.maxOutputTokens)
        normalized.criticalFreeRAMFloorMB = constraints.criticalFreeRAMFloorMB.roundedToStep(settings.criticalFreeRAMFloorMB)
        normalized.mlxCacheLimitMB = constraints.mlxCacheLimitMB.roundedToStep(settings.mlxCacheLimitMB)
        normalized.mlxMaxKVSizeTokens = contextWindowTokenLimit(
            settings.mlxMaxKVSizeTokens,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens
        )
        normalized.mlxKVBits = [0, 4, 8].contains(settings.mlxKVBits) ? settings.mlxKVBits : LLMRuntimeSettings.recommended.mlxKVBits
        normalized.mlxPrefillStepSize = constraints.mlxPrefillStepSize.roundedToStep(settings.mlxPrefillStepSize)
        normalized.ggufContextWindowTokens = contextWindowTokenLimit(
            settings.ggufContextWindowTokens,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens
        )
        normalized.ggufBatchSize = constraints.ggufBatchSize.roundedToStep(settings.ggufBatchSize)
        normalized.ggufThreadCount = settings.ggufThreadCount.map { constraints.ggufThreadCount.clamped($0) }
        if case .custom(let layerCount) = settings.ggufGPUOffloadPolicy {
            normalized.ggufGPUOffloadPolicy = .custom(layerCount: constraints.ggufCustomGPULayers.clamped(layerCount))
        }
        return normalized
    }

    public func effectiveSettings(
        for settings: LLMRuntimeSettings,
        selectedModelContextWindowTokens: Int? = nil,
        isLowMemoryConstrained: Bool = false
    ) -> LLMEffectiveSettings {
        let normalizedSettings = normalized(
            settings,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens
        )
        let unclampedInput = contextWindowTokenLimit(
            normalizedSettings.contextWindowTokens,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens
        )
        let unclampedOutput = constraints.outputTokens.clamped(normalizedSettings.maxOutputTokens)
        let inputTokens = isLowMemoryConstrained ? min(unclampedInput, constraints.lowMemoryContextWindowTokens) : unclampedInput
        let outputTokens = isLowMemoryConstrained ? min(unclampedOutput, constraints.lowMemoryMaxOutputTokens) : unclampedOutput
        let mlxKVSize = min(normalizedSettings.mlxMaxKVSizeTokens, inputTokens)
        let ggufContext = normalizedSettings.ggufContextFollowsRequest
            ? inputTokens
            : contextWindowTokenLimit(
                normalizedSettings.ggufContextWindowTokens,
                selectedModelContextWindowTokens: selectedModelContextWindowTokens
            )
        return LLMEffectiveSettings(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            mlxKVSizeTokens: mlxKVSize,
            ggufContextSizeTokens: ggufContext,
            criticalFreeRAMFloorBytes: Int64(normalizedSettings.criticalFreeRAMFloorMB) * 1_000_000
        )
    }

    public func executionBudget(
        for settings: LLMRuntimeSettings,
        selectedModelContextWindowTokens: Int? = nil,
        isLowMemoryConstrained: Bool = false
    ) -> ExecutionBudget {
        let effective = effectiveSettings(
            for: settings,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens,
            isLowMemoryConstrained: isLowMemoryConstrained
        )
        return ExecutionBudget(maxInputTokens: effective.inputTokens, maxOutputTokens: effective.outputTokens)
    }

    private func contextWindowTokenLimit(
        _ value: Int,
        selectedModelContextWindowTokens: Int?
    ) -> Int {
        let maximum = min(
            constraints.contextWindowTokens.maximum,
            selectedModelContextWindowTokens ?? constraints.contextWindowTokens.maximum
        )
        let modelAwareBounds = LLMIntegerSettingBounds(
            minimum: min(constraints.contextWindowTokens.minimum, maximum),
            maximum: maximum,
            step: constraints.contextWindowTokens.step
        )
        return modelAwareBounds.roundedToStep(value)
    }
}
