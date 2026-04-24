import Foundation
import LLMCore
import LLMProtocols

public struct DefaultStructuredGenerationService: StructuredGenerationService {
    private let generation: any LanguageGenerationService
    private let decoder: JSONDecoder

    public init(generation: any LanguageGenerationService, decoder: JSONDecoder = JSONDecoder()) {
        self.generation = generation
        self.decoder = decoder
    }

    public func generate<T: Decodable & Sendable>(_ type: T.Type, request: StructuredRequest) async throws -> T {
        let result = try await generation.generate(GenerationRequest(
            prompt: request.prompt,
            structuredOutputSchema: request.schema,
            requirements: request.requirements,
            sessionID: request.sessionID
        ))
        guard let data = result.text.data(using: .utf8) else {
            throw LLMError.invalidStructuredOutput("Response was not UTF-8.")
        }
        return try decoder.decode(T.self, from: data)
    }
}
