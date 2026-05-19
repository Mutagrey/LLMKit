import Foundation
import LLMCore

public struct LlamaCppRuntimeReport: Hashable, Sendable {
    public let supportsMMap: Bool
    public let usesMMap: Bool
    public let supportsGPUOffload: Bool
    public let requestedGPULayerCount: Int
    public let effectiveGPULayerCount: Int
    public let supportsQuantizedKVCache: Bool
    public let requestedKVCachePolicy: KVCachePolicy
    public let effectiveKVCachePolicy: KVCachePolicy
    public let kvCacheFallbackReason: String?
    public let metalExecutionVerified: Bool

    public init(
        supportsMMap: Bool,
        usesMMap: Bool,
        supportsGPUOffload: Bool,
        requestedGPULayerCount: Int,
        effectiveGPULayerCount: Int,
        supportsQuantizedKVCache: Bool,
        requestedKVCachePolicy: KVCachePolicy,
        effectiveKVCachePolicy: KVCachePolicy,
        kvCacheFallbackReason: String?,
        metalExecutionVerified: Bool
    ) {
        self.supportsMMap = supportsMMap
        self.usesMMap = usesMMap
        self.supportsGPUOffload = supportsGPUOffload
        self.requestedGPULayerCount = requestedGPULayerCount
        self.effectiveGPULayerCount = effectiveGPULayerCount
        self.supportsQuantizedKVCache = supportsQuantizedKVCache
        self.requestedKVCachePolicy = requestedKVCachePolicy
        self.effectiveKVCachePolicy = effectiveKVCachePolicy
        self.kvCacheFallbackReason = kvCacheFallbackReason
        self.metalExecutionVerified = metalExecutionVerified
    }

    static func resolved(
        configuration: LlamaCppRuntimeConfiguration,
        supportsMMap: Bool,
        supportsGPUOffload: Bool,
        supportsQuantizedKVCache: Bool = false,
        isSimulator: Bool
    ) -> LlamaCppRuntimeReport {
        let requestedGPULayerCount = configuration.resolvedGPULayerCount(isSimulator: isSimulator)
        let effectiveGPULayerCount = supportsGPUOffload ? requestedGPULayerCount : 0
        let effectiveKVCachePolicy = configuration.kvCachePolicy.resolved(
            supportsQuantizedKVCache: supportsQuantizedKVCache
        )
        let kvCacheFallbackReason = effectiveKVCachePolicy == configuration.kvCachePolicy
            ? nil
            : "Requested KV cache policy requires quantized KV cache support."
        return LlamaCppRuntimeReport(
            supportsMMap: supportsMMap,
            usesMMap: configuration.resolvedUseMMap(isSupported: supportsMMap),
            supportsGPUOffload: supportsGPUOffload,
            requestedGPULayerCount: requestedGPULayerCount,
            effectiveGPULayerCount: effectiveGPULayerCount,
            supportsQuantizedKVCache: supportsQuantizedKVCache,
            requestedKVCachePolicy: configuration.kvCachePolicy,
            effectiveKVCachePolicy: effectiveKVCachePolicy,
            kvCacheFallbackReason: kvCacheFallbackReason,
            metalExecutionVerified: false
        )
    }
}
