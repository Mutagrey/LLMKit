import Foundation

public enum PromptCachePolicy: String, Hashable, Codable, Sendable {
    case disabled
    case basePromptReadOnly
    case sessionReadWrite

    public static let defaultPolicy: PromptCachePolicy = .disabled
}

public struct PromptCacheKey: Hashable, Codable, Sendable {
    public let modelId: ModelID
    public let modelFileHash: String
    public let systemPromptVersion: String
    public let contextSize: Int
    public let kvCachePolicy: KVCachePolicy

    public init(
        modelId: ModelID,
        modelFileHash: String,
        systemPromptVersion: String,
        contextSize: Int,
        kvCachePolicy: KVCachePolicy
    ) {
        self.modelId = modelId
        self.modelFileHash = modelFileHash
        self.systemPromptVersion = systemPromptVersion
        self.contextSize = max(1, contextSize)
        self.kvCachePolicy = kvCachePolicy
    }
}
