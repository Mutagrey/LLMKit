import Foundation

public enum LLMSettingsPreset: String, CaseIterable, Hashable, Codable, Sendable {
    case recommended
    case memorySaving
    case performance
    case defaults

    public var settings: LLMRuntimeSettings {
        switch self {
        case .recommended, .defaults:
            return .recommended
        case .memorySaving:
            return LLMRuntimeSettings(
                contextWindowTokens: 4_096,
                maxOutputTokens: 384,
                criticalFreeRAMFloorMB: 768,
                mlxCacheLimitMB: 64,
                mlxMaxKVSizeTokens: 4_096,
                mlxKVBits: 4,
                mlxPrefillStepSize: 128,
                mlxRetainChatSessions: false,
                mlxClearCacheAfterGeneration: true,
                mlxClearCacheOnUnload: true,
                ggufContextFollowsRequest: true,
                ggufGPUOffloadPolicy: .automatic,
                ggufBatchSize: 128
            )
        case .performance:
            return LLMRuntimeSettings(
                contextWindowTokens: 16_384,
                maxOutputTokens: 1_024,
                criticalFreeRAMFloorMB: 512,
                mlxCacheLimitMB: 256,
                mlxMaxKVSizeTokens: 16_384,
                mlxKVBits: 0,
                mlxPrefillStepSize: 512,
                mlxRetainChatSessions: true,
                mlxClearCacheAfterGeneration: false,
                mlxClearCacheOnUnload: true,
                ggufContextFollowsRequest: true,
                ggufGPUOffloadPolicy: .automatic,
                ggufBatchSize: 512
            )
        }
    }
}
