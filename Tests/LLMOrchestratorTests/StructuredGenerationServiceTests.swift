import Foundation
import LLMCore
import LLMOrchestrator
import LLMProtocols
import Testing

private final class RecordingGenerationService: LanguageGenerationService, @unchecked Sendable {
    private let responseText: String
    private let state = State()

    init(responseText: String) {
        self.responseText = responseText
    }

    func generate(_ request: GenerationRequest) async throws -> GenerationResult {
        await state.record(request)
        return GenerationResult(text: responseText)
    }

    func stream(_ request: GenerationRequest) -> AsyncThrowingStream<GenerationEvent, Error> {
        let text = responseText
        return AsyncThrowingStream { continuation in
            let model = ModelDescriptor(
                id: "structured-test-model",
                displayName: "Structured Test Model",
                family: .custom("structured-test"),
                backend: .remote,
                capabilities: [.completion, .structuredOutput]
            )
            continuation.yield(.started(model))
            continuation.yield(.delta(text))
            continuation.yield(.completed(GenerationResult(text: text, model: model)))
            continuation.finish()
        }
    }

    func recordedRequests() async -> [GenerationRequest] {
        await state.snapshot()
    }

    private actor State {
        private var requests: [GenerationRequest] = []

        func record(_ request: GenerationRequest) {
            requests.append(request)
        }

        func snapshot() -> [GenerationRequest] {
            requests
        }
    }
}

private struct WeatherSummary: Codable, Equatable, Sendable {
    let city: String
    let forecast: String
}

@Test func structuredGenerationServiceEmbedsSchemaInstructionsInPrompt() async throws {
    let generation = RecordingGenerationService(responseText: #"{"city":"Paris","forecast":"Sunny"}"#)
    let service = DefaultStructuredGenerationService(generation: generation)
    let schema = StructuredOutputSchema(name: "WeatherSummary", definition: [
        "type": .string("object"),
        "properties": .object([
            "city": .object(["type": .string("string")]),
            "forecast": .object(["type": .string("string")])
        ]),
        "required": .array([.string("city"), .string("forecast")]),
        "additionalProperties": .boolean(false)
    ])

    let result = try await service.generate(
        WeatherSummary.self,
        request: StructuredRequest(prompt: "Summarize Paris weather.", schema: schema, sessionID: "session-structured")
    )

    let recorded = await generation.recordedRequests()
    #expect(result == WeatherSummary(city: "Paris", forecast: "Sunny"))
    #expect(recorded.count == 1)
    #expect(recorded[0].sessionID == "session-structured")
    #expect(recorded[0].prompt == "Summarize Paris weather.")
    #expect(recorded[0].structuredOutputSchema == schema)
    #expect(recorded[0].renderedPrompt.contains("Return only valid JSON"))
    #expect(recorded[0].renderedPrompt.contains("Schema name: WeatherSummary"))
    #expect(recorded[0].renderedPrompt.contains(#""additionalProperties":false"#))
}

@Test func structuredGenerationServicePreservesPromptWhenSchemaIsMissing() async throws {
    let generation = RecordingGenerationService(responseText: #"{"city":"Paris","forecast":"Sunny"}"#)
    let service = DefaultStructuredGenerationService(generation: generation)

    _ = try await service.generate(
        WeatherSummary.self,
        request: StructuredRequest(prompt: "Summarize Paris weather.")
    )

    let recorded = await generation.recordedRequests()
    #expect(recorded.count == 1)
    #expect(recorded[0].prompt == "Summarize Paris weather.")
    #expect(recorded[0].structuredOutputSchema == nil)
    #expect(recorded[0].renderedPrompt == "Summarize Paris weather.")
}
