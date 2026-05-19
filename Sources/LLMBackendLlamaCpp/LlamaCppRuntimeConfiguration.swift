import Foundation

public struct LlamaCppRuntimeConfiguration: Hashable, Sendable {
    public let contextSize: Int
    public let maxLoadedModels: Int
    public let useMMap: Bool
    public let useMetal: Bool
    public let gpuLayerCount: Int
    public let threadCount: Int?
    public let batchSize: Int

    public init(
        contextSize: Int = 2048,
        maxLoadedModels: Int = 1,
        useMMap: Bool = true,
        useMetal: Bool = true,
        gpuLayerCount: Int = 99,
        threadCount: Int? = nil,
        batchSize: Int = 256
    ) {
        self.contextSize = max(1, contextSize)
        self.maxLoadedModels = max(1, maxLoadedModels)
        self.useMMap = useMMap
        self.useMetal = useMetal
        self.gpuLayerCount = useMetal ? max(0, gpuLayerCount) : 0
        self.threadCount = threadCount.map { max(1, $0) }
        self.batchSize = max(1, batchSize)
    }

    public static let `default` = LlamaCppRuntimeConfiguration()

    func resolvedUseMMap(isSupported: Bool) -> Bool {
        useMMap && isSupported
    }

    func resolvedGPULayerCount(isSimulator: Bool = LlamaCppRuntimeConfiguration.isSimulatorEnvironment) -> Int {
        guard useMetal, !isSimulator else {
            return 0
        }
        return gpuLayerCount
    }

    private static var isSimulatorEnvironment: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
