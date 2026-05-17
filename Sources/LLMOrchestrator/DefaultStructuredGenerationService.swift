import Foundation
import LLMCore
import LLMProtocols

public struct DefaultStructuredGenerationService: StructuredGenerationService {
    private let generation: any LanguageGenerationService
    private let decoder: JSONDecoder
    private let repairAttempts: Int

    public init(
        generation: any LanguageGenerationService,
        decoder: JSONDecoder = JSONDecoder(),
        repairAttempts: Int = 1
    ) {
        self.generation = generation
        self.decoder = decoder
        self.repairAttempts = max(0, repairAttempts)
    }

    public func generate<T: Decodable & Sendable>(_ type: T.Type, request: StructuredRequest) async throws -> T {
        let result = try await generation.generate(generationRequest(for: request))
        do {
            return try decode(type, from: result.text)
        } catch {
            guard repairAttempts > 0 else {
                throw invalidStructuredOutputError(schema: request.schema, error: error)
            }
            return try await repairAndDecode(type, request: request, invalidText: result.text, error: error)
        }
    }

    private func repairAndDecode<T: Decodable & Sendable>(
        _ type: T.Type,
        request: StructuredRequest,
        invalidText: String,
        error: Error
    ) async throws -> T {
        let repairRequest = StructuredRequest(
            prompt: repairPrompt(for: request, invalidText: invalidText, error: error),
            schema: request.schema,
            requirements: request.requirements,
            sessionID: request.sessionID
        )
        let result = try await generation.generate(generationRequest(for: repairRequest))
        do {
            return try decode(type, from: result.text)
        } catch {
            throw invalidStructuredOutputError(schema: request.schema, error: error)
        }
    }

    private func generationRequest(for request: StructuredRequest) -> GenerationRequest {
        GenerationRequest(
            prompt: request.prompt,
            structuredOutputSchema: request.schema,
            requirements: request.requirements,
            sessionID: request.sessionID
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let data = text.data(using: .utf8) else {
            throw LLMError.invalidStructuredOutput("Response was not UTF-8.")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func repairPrompt(for request: StructuredRequest, invalidText: String, error: Error) -> String {
        [
            request.prompt,
            "The previous response was not valid JSON for the requested schema.",
            "Decoder error: \(String(describing: error))",
            "Invalid response:",
            invalidText,
            "Return only corrected valid JSON. Do not include markdown, prose, or code fences."
        ].joined(separator: "\n\n")
    }

    private func invalidStructuredOutputError(schema: StructuredOutputSchema?, error: Error) -> LLMError {
        let schemaName = schema?.name.map { " for \($0)" } ?? ""
        return .invalidStructuredOutput("Response did not match the requested JSON schema\(schemaName): \(String(describing: error))")
    }
}
