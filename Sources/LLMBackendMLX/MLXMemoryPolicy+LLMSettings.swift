import Foundation
import LLMSettings

public extension MLXMemoryPolicy {
    init(settings: LLMRuntimeSettings, effectiveKVSizeTokens: Int? = nil) {
        let kvBits = [4, 8].contains(settings.mlxKVBits) ? settings.mlxKVBits : nil
        self.init(
            cacheLimitBytes: settings.mlxCacheLimitMB * 1_024 * 1_024,
            clearCacheAfterGeneration: settings.mlxClearCacheAfterGeneration,
            clearCacheOnUnload: settings.mlxClearCacheOnUnload,
            maxLoadedModels: 1,
            retainChatSessions: settings.mlxRetainChatSessions,
            maxKVSize: effectiveKVSizeTokens ?? settings.mlxMaxKVSizeTokens,
            kvBits: kvBits,
            kvGroupSize: 64,
            quantizedKVStart: 0,
            prefillStepSize: settings.mlxPrefillStepSize
        )
    }
}
