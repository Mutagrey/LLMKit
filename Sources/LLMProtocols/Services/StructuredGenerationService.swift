import LLMCore

public protocol StructuredGenerationService: Sendable {
    func generate<T: Decodable & Sendable>(_ type: T.Type, request: StructuredRequest) async throws -> T
}
