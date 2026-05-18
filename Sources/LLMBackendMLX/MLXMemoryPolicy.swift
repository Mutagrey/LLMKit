import Foundation

public struct MLXMemoryPolicy: Hashable, Sendable {
    public let cacheLimitBytes: Int?
    public let clearCacheAfterGeneration: Bool
    public let clearCacheOnUnload: Bool
    public let maxLoadedModels: Int?
    public let retainChatSessions: Bool
    public let maxKVSize: Int?
    public let kvBits: Int?
    public let kvGroupSize: Int
    public let quantizedKVStart: Int
    public let prefillStepSize: Int?

    public init(
        cacheLimitBytes: Int? = nil,
        clearCacheAfterGeneration: Bool = false,
        clearCacheOnUnload: Bool = false,
        maxLoadedModels: Int? = nil,
        retainChatSessions: Bool = true,
        maxKVSize: Int? = nil,
        kvBits: Int? = nil,
        kvGroupSize: Int = 64,
        quantizedKVStart: Int = 0,
        prefillStepSize: Int? = nil
    ) {
        self.cacheLimitBytes = cacheLimitBytes
        self.clearCacheAfterGeneration = clearCacheAfterGeneration
        self.clearCacheOnUnload = clearCacheOnUnload
        self.maxLoadedModels = maxLoadedModels.map { max(1, $0) }
        self.retainChatSessions = retainChatSessions
        self.maxKVSize = maxKVSize.map { max(1, $0) }
        self.kvBits = kvBits
        self.kvGroupSize = max(1, kvGroupSize)
        self.quantizedKVStart = max(0, quantizedKVStart)
        self.prefillStepSize = prefillStepSize.map { max(1, $0) }
    }

    public static let `default` = MLXMemoryPolicy()

    public static let strictForMemoryConstrainedApps = MLXMemoryPolicy(
        cacheLimitBytes: 64 * 1024 * 1024,
        clearCacheAfterGeneration: true,
        clearCacheOnUnload: true,
        maxLoadedModels: 1,
        retainChatSessions: false,
        maxKVSize: 8_192,
        kvBits: 4,
        kvGroupSize: 64,
        quantizedKVStart: 0,
        prefillStepSize: 256
    )
}
