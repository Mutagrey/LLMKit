import Foundation
import LLMCore
import Testing

@Test func modelDescriptorRoundTripsThroughCodable() throws {
    let descriptor = ModelDescriptor(
        id: "apple-foundation-default",
        displayName: "Apple Foundation Default",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat, .streaming],
        supportsStreaming: true
    )

    let data = try JSONEncoder().encode(descriptor)
    let decoded = try JSONDecoder().decode(ModelDescriptor.self, from: data)

    #expect(decoded == descriptor)
}

@Test func generationRequestCarriesExecutionRequirements() {
    let requirements = ExecutionRequirements(
        requiredCapabilities: [.completion, .offline],
        executionMode: .offlineOnly,
        preferredLatency: .interactive,
        qualityTier: .fast,
        preferredModel: "local-fast"
    )
    let request = GenerationRequest(prompt: "Summarize", requirements: requirements, sessionID: "session-1")

    #expect(request.requirements.requiredCapabilities.contains(.offline))
    #expect(request.sessionID == "session-1")
}

@Test func lifecycleStatesAreEquatable() {
    #expect(InstallState.downloading(progress: 0.5) == .downloading(progress: 0.5))
    #expect(LLMError.modelNotInstalled("missing") == .modelNotInstalled("missing"))
}

@Test func streamedTextAccumulatorAppendsDeltas() {
    var accumulator = StreamedTextAccumulator()

    accumulator.append("hel")
    accumulator.append("lo")

    #expect(accumulator.text == "hello")
    #expect(!accumulator.isEmpty)
}
