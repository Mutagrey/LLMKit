import Foundation

public struct LLMEffectiveSettings: Hashable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let mlxKVSizeTokens: Int
    public let ggufContextSizeTokens: Int
    public let criticalFreeRAMFloorBytes: Int64

    public init(
        inputTokens: Int,
        outputTokens: Int,
        mlxKVSizeTokens: Int,
        ggufContextSizeTokens: Int,
        criticalFreeRAMFloorBytes: Int64
    ) {
        self.inputTokens = max(1, inputTokens)
        self.outputTokens = max(1, outputTokens)
        self.mlxKVSizeTokens = max(1, mlxKVSizeTokens)
        self.ggufContextSizeTokens = max(1, ggufContextSizeTokens)
        self.criticalFreeRAMFloorBytes = max(0, criticalFreeRAMFloorBytes)
    }
}
