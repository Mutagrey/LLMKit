import Foundation

public struct LlamaCppRuntimeConfiguration: Hashable, Sendable {
    public let contextSize: Int
    public let maxLoadedModels: Int
    public let useMetal: Bool
    public let threadCount: Int?
    public let batchSize: Int

    public init(
        contextSize: Int = 4096,
        maxLoadedModels: Int = 1,
        useMetal: Bool = true,
        threadCount: Int? = nil,
        batchSize: Int = 512
    ) {
        self.contextSize = max(1, contextSize)
        self.maxLoadedModels = max(1, maxLoadedModels)
        self.useMetal = useMetal
        self.threadCount = threadCount.map { max(1, $0) }
        self.batchSize = max(1, batchSize)
    }

    public static let `default` = LlamaCppRuntimeConfiguration()
}
