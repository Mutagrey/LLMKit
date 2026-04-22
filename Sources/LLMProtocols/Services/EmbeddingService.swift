import LLMCore

public protocol EmbeddingService: Sendable {
    func embed(_ request: EmbeddingRequest) async throws -> EmbeddingResult
}
