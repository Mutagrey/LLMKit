import Foundation

public struct GenerationResult: Hashable, Codable, Sendable {
    public let text: String
    public let model: ModelDescriptor?
    public let usage: UsageMetrics?
    public let finishReason: StreamFinishReason

    public init(text: String, model: ModelDescriptor? = nil, usage: UsageMetrics? = nil, finishReason: StreamFinishReason = .completed) {
        self.text = text
        self.model = model
        self.usage = usage
        self.finishReason = finishReason
    }
}

public struct ChatResult: Hashable, Codable, Sendable {
    public let message: ChatMessage
    public let model: ModelDescriptor?
    public let usage: UsageMetrics?
    public let finishReason: StreamFinishReason

    public init(message: ChatMessage, model: ModelDescriptor? = nil, usage: UsageMetrics? = nil, finishReason: StreamFinishReason = .completed) {
        self.message = message
        self.model = model
        self.usage = usage
        self.finishReason = finishReason
    }
}

public struct StructuredGenerationResult: Hashable, Codable, Sendable {
    public let rawText: String
    public let schemaName: String?

    public init(rawText: String, schemaName: String? = nil) {
        self.rawText = rawText
        self.schemaName = schemaName
    }
}

public struct EmbeddingVector: Hashable, Codable, Sendable {
    public let values: [Double]

    public init(values: [Double]) {
        self.values = values
    }
}

public struct EmbeddingResult: Hashable, Codable, Sendable {
    public let vector: EmbeddingVector
    public let model: ModelDescriptor?

    public init(vector: EmbeddingVector, model: ModelDescriptor? = nil) {
        self.vector = vector
        self.model = model
    }
}
