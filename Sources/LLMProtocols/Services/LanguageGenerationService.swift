import LLMCore

public protocol LanguageGenerationService: Sendable {
    func generate(_ request: GenerationRequest) async throws -> GenerationResult
    func stream(_ request: GenerationRequest) -> AsyncThrowingStream<GenerationEvent, Error>
}

public typealias GenerationService = LanguageGenerationService
