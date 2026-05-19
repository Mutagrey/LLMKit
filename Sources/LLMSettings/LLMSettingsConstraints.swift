import Foundation

public struct LLMSettingsConstraints: Hashable, Codable, Sendable {
    public var contextWindowTokens: LLMIntegerSettingBounds
    public var outputTokens: LLMIntegerSettingBounds
    public var criticalFreeRAMFloorMB: LLMIntegerSettingBounds
    public var mlxCacheLimitMB: LLMIntegerSettingBounds
    public var mlxMaxKVSizeTokens: LLMIntegerSettingBounds
    public var mlxPrefillStepSize: LLMIntegerSettingBounds
    public var ggufBatchSize: LLMIntegerSettingBounds
    public var ggufThreadCount: LLMIntegerSettingBounds
    public var ggufCustomGPULayers: LLMIntegerSettingBounds
    public var lowMemoryContextWindowTokens: Int
    public var lowMemoryMaxOutputTokens: Int

    public init(
        contextWindowTokens: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 2_048, maximum: 32_768, step: 1_024),
        outputTokens: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 128, maximum: 4_096, step: 128),
        criticalFreeRAMFloorMB: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 256, maximum: 2_048, step: 128),
        mlxCacheLimitMB: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 64, maximum: 512, step: 32),
        mlxMaxKVSizeTokens: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 2_048, maximum: 32_768, step: 1_024),
        mlxPrefillStepSize: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 128, maximum: 1_024, step: 128),
        ggufBatchSize: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 64, maximum: 1_024, step: 64),
        ggufThreadCount: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 1, maximum: 16, step: 1),
        ggufCustomGPULayers: LLMIntegerSettingBounds = LLMIntegerSettingBounds(minimum: 0, maximum: 99, step: 1),
        lowMemoryContextWindowTokens: Int = 8_192,
        lowMemoryMaxOutputTokens: Int = 512
    ) {
        self.contextWindowTokens = contextWindowTokens
        self.outputTokens = outputTokens
        self.criticalFreeRAMFloorMB = criticalFreeRAMFloorMB
        self.mlxCacheLimitMB = mlxCacheLimitMB
        self.mlxMaxKVSizeTokens = mlxMaxKVSizeTokens
        self.mlxPrefillStepSize = mlxPrefillStepSize
        self.ggufBatchSize = ggufBatchSize
        self.ggufThreadCount = ggufThreadCount
        self.ggufCustomGPULayers = ggufCustomGPULayers
        self.lowMemoryContextWindowTokens = max(1, lowMemoryContextWindowTokens)
        self.lowMemoryMaxOutputTokens = max(1, lowMemoryMaxOutputTokens)
    }

    public static let recommended = LLMSettingsConstraints()
}
