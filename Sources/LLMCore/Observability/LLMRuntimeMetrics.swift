import Foundation

public struct LLMRuntimeMetrics: Hashable, Codable, Sendable {
    public let modelLoadTimeMilliseconds: Int?
    public let warmupTimeMilliseconds: Int?
    public let timeToFirstTokenMilliseconds: Int?
    public let generationTimeMilliseconds: Int?
    public let tokensPerSecond: Double?
    public let memoryBeforeLoadBytes: UInt64?
    public let memoryAfterLoadBytes: UInt64?
    public let memoryAfterGenerationBytes: UInt64?

    public init(
        modelLoadTimeMilliseconds: Int? = nil,
        warmupTimeMilliseconds: Int? = nil,
        timeToFirstTokenMilliseconds: Int? = nil,
        generationTimeMilliseconds: Int? = nil,
        tokensPerSecond: Double? = nil,
        memoryBeforeLoadBytes: UInt64? = nil,
        memoryAfterLoadBytes: UInt64? = nil,
        memoryAfterGenerationBytes: UInt64? = nil
    ) {
        self.modelLoadTimeMilliseconds = modelLoadTimeMilliseconds
        self.warmupTimeMilliseconds = warmupTimeMilliseconds
        self.timeToFirstTokenMilliseconds = timeToFirstTokenMilliseconds
        self.generationTimeMilliseconds = generationTimeMilliseconds
        self.tokensPerSecond = tokensPerSecond
        self.memoryBeforeLoadBytes = memoryBeforeLoadBytes
        self.memoryAfterLoadBytes = memoryAfterLoadBytes
        self.memoryAfterGenerationBytes = memoryAfterGenerationBytes
    }

    public func sanitizedMetadata(prefix: String = "runtime") -> [String: String] {
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        var metadata: [String: String] = [:]

        func key(_ name: String) -> String {
            normalizedPrefix.isEmpty ? name : "\(normalizedPrefix).\(name)"
        }

        if let modelLoadTimeMilliseconds {
            metadata[key("model_load_time_ms")] = "\(modelLoadTimeMilliseconds)"
        }
        if let warmupTimeMilliseconds {
            metadata[key("warmup_time_ms")] = "\(warmupTimeMilliseconds)"
        }
        if let timeToFirstTokenMilliseconds {
            metadata[key("time_to_first_token_ms")] = "\(timeToFirstTokenMilliseconds)"
        }
        if let generationTimeMilliseconds {
            metadata[key("generation_time_ms")] = "\(generationTimeMilliseconds)"
        }
        if let tokensPerSecond {
            metadata[key("tokens_per_second")] = "\(tokensPerSecond)"
        }
        if let memoryBeforeLoadBytes {
            metadata[key("memory_before_load_bytes")] = "\(memoryBeforeLoadBytes)"
        }
        if let memoryAfterLoadBytes {
            metadata[key("memory_after_load_bytes")] = "\(memoryAfterLoadBytes)"
        }
        if let memoryAfterGenerationBytes {
            metadata[key("memory_after_generation_bytes")] = "\(memoryAfterGenerationBytes)"
        }

        return metadata
    }
}
