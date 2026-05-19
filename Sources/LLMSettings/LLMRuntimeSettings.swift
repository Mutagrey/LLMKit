import Foundation
import LLMCore

public struct LLMRuntimeSettings: Hashable, Codable, Sendable {
    public var preferredModelID: ModelID?
    public var executionMode: ExecutionMode
    public var qualityTier: QualityTier
    public var privacyMode: PrivacyMode

    public var contextWindowTokens: Int
    public var maxOutputTokens: Int

    public var criticalFreeRAMFloorMB: Int

    public var mlxCacheLimitMB: Int
    public var mlxMaxKVSizeTokens: Int
    public var mlxKVBits: Int
    public var mlxPrefillStepSize: Int
    public var mlxRetainChatSessions: Bool
    public var mlxClearCacheAfterGeneration: Bool
    public var mlxClearCacheOnUnload: Bool

    public var ggufContextFollowsRequest: Bool
    public var ggufContextWindowTokens: Int
    public var ggufUseMMap: Bool
    public var ggufGPUOffloadPolicy: LLMGPUOffloadPolicy
    public var ggufKVCachePolicy: KVCachePolicy
    public var ggufThreadCount: Int?
    public var ggufBatchSize: Int

    public init(
        preferredModelID: ModelID? = nil,
        executionMode: ExecutionMode = .preferOffline,
        qualityTier: QualityTier = .balanced,
        privacyMode: PrivacyMode = .localOnly,
        contextWindowTokens: Int = 8_192,
        maxOutputTokens: Int = 512,
        criticalFreeRAMFloorMB: Int = 512,
        mlxCacheLimitMB: Int = 128,
        mlxMaxKVSizeTokens: Int = 8_192,
        mlxKVBits: Int = 4,
        mlxPrefillStepSize: Int = 256,
        mlxRetainChatSessions: Bool = true,
        mlxClearCacheAfterGeneration: Bool = false,
        mlxClearCacheOnUnload: Bool = true,
        ggufContextFollowsRequest: Bool = true,
        ggufContextWindowTokens: Int = 8_192,
        ggufUseMMap: Bool = true,
        ggufGPUOffloadPolicy: LLMGPUOffloadPolicy = .automatic,
        ggufKVCachePolicy: KVCachePolicy = .runtimeDefault,
        ggufThreadCount: Int? = nil,
        ggufBatchSize: Int = 256
    ) {
        self.preferredModelID = preferredModelID
        self.executionMode = executionMode
        self.qualityTier = qualityTier
        self.privacyMode = privacyMode
        self.contextWindowTokens = contextWindowTokens
        self.maxOutputTokens = maxOutputTokens
        self.criticalFreeRAMFloorMB = criticalFreeRAMFloorMB
        self.mlxCacheLimitMB = mlxCacheLimitMB
        self.mlxMaxKVSizeTokens = mlxMaxKVSizeTokens
        self.mlxKVBits = mlxKVBits
        self.mlxPrefillStepSize = mlxPrefillStepSize
        self.mlxRetainChatSessions = mlxRetainChatSessions
        self.mlxClearCacheAfterGeneration = mlxClearCacheAfterGeneration
        self.mlxClearCacheOnUnload = mlxClearCacheOnUnload
        self.ggufContextFollowsRequest = ggufContextFollowsRequest
        self.ggufContextWindowTokens = ggufContextWindowTokens
        self.ggufUseMMap = ggufUseMMap
        self.ggufGPUOffloadPolicy = ggufGPUOffloadPolicy
        self.ggufKVCachePolicy = ggufKVCachePolicy
        self.ggufThreadCount = ggufThreadCount
        self.ggufBatchSize = ggufBatchSize
    }

    public static let recommended = LLMRuntimeSettings()

    public mutating func applyPreset(_ preset: LLMSettingsPreset) {
        self = preset.settings
    }

    public mutating func resetRouting() {
        preferredModelID = Self.recommended.preferredModelID
        executionMode = Self.recommended.executionMode
        qualityTier = Self.recommended.qualityTier
        privacyMode = Self.recommended.privacyMode
    }

    public mutating func resetGeneration() {
        contextWindowTokens = Self.recommended.contextWindowTokens
        maxOutputTokens = Self.recommended.maxOutputTokens
    }

    public mutating func resetMemory() {
        criticalFreeRAMFloorMB = Self.recommended.criticalFreeRAMFloorMB
    }

    public mutating func resetMLX() {
        mlxCacheLimitMB = Self.recommended.mlxCacheLimitMB
        mlxMaxKVSizeTokens = Self.recommended.mlxMaxKVSizeTokens
        mlxKVBits = Self.recommended.mlxKVBits
        mlxPrefillStepSize = Self.recommended.mlxPrefillStepSize
        mlxRetainChatSessions = Self.recommended.mlxRetainChatSessions
        mlxClearCacheAfterGeneration = Self.recommended.mlxClearCacheAfterGeneration
        mlxClearCacheOnUnload = Self.recommended.mlxClearCacheOnUnload
    }

    public mutating func resetGGUF() {
        ggufContextFollowsRequest = Self.recommended.ggufContextFollowsRequest
        ggufContextWindowTokens = Self.recommended.ggufContextWindowTokens
        ggufUseMMap = Self.recommended.ggufUseMMap
        ggufGPUOffloadPolicy = Self.recommended.ggufGPUOffloadPolicy
        ggufKVCachePolicy = Self.recommended.ggufKVCachePolicy
        ggufThreadCount = Self.recommended.ggufThreadCount
        ggufBatchSize = Self.recommended.ggufBatchSize
    }
}
