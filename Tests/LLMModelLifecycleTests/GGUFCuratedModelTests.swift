import LLMCore
import LLMModelLifecycle
import Testing

@Test func curatedGGUFModelsUseLlamaCppBackendAndSingleGGUFArtifact() throws {
    let models = CuratedModelManifests.localIPhoneGGUFTextModels.models

    #expect(models.map(\.id.rawValue) == [
        "bartowski.Llama-3.2-1B-Instruct-GGUF.Q4_K_M",
        "bartowski.Llama-3.2-3B-Instruct-GGUF.Q4_K_M"
    ])

    for model in models {
        let artifact = try #require(model.source?.artifacts.first)
        #expect(model.backend == .llamaCpp)
        #expect(model.family == .llama)
        #expect(model.quantization == Quantization(format: "GGUF Q4_K_M", bits: 4))
        #expect(model.supportsStreaming)
        #expect(model.source?.artifacts.count == 1)
        #expect(artifact.relativePath.hasSuffix(".gguf"))
        #expect(artifact.byteCount != nil)
    }
}
