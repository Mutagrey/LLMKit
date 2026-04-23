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

@Test func downloadableModelDescriptorCarriesSourceArtifacts() throws {
    let descriptor = ModelDescriptor(
        id: "local-qwen",
        displayName: "Local Qwen",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: 278_000_000
                )
            ]
        ),
        license: ModelLicense(name: "Apache License 2.0", spdxIdentifier: "Apache-2.0"),
        quantization: Quantization(format: "MLX 4-bit", bits: 4),
        estimatedDownloadSizeBytes: 290_000_000
    )

    let data = try JSONEncoder().encode(descriptor)
    let decoded = try JSONDecoder().decode(ModelDescriptor.self, from: data)

    #expect(decoded.source?.provider == .huggingFace)
    #expect(decoded.source?.artifacts.first?.relativePath == "model.safetensors")
    #expect(decoded.license?.spdxIdentifier == "Apache-2.0")
    #expect(decoded.quantization?.bits == 4)
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
