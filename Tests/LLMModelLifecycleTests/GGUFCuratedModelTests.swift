import LLMCore
import LLMModelLifecycle
import Testing

@Test func curatedGGUFModelsUseLlamaCppBackendAndSingleGGUFArtifact() throws {
    let models = CuratedModelManifests.localIPhoneGGUFTextModels.models

    #expect(models.map(\.id.rawValue) == [
        "bartowski.google_gemma-3-1b-it-GGUF.Q4_K_M",
        "bartowski.Llama-3.2-1B-Instruct-GGUF.Q4_K_M",
        "bartowski.google_gemma-3-4b-it-GGUF.Q4_K_M",
        "bartowski.google_gemma-4-E2B-it-GGUF.Q4_K_M",
        "bartowski.Qwen_Qwen3-4B-Instruct-2507-GGUF.Q4_K_M",
        "bartowski.Qwen_Qwen3-8B-GGUF.Q4_K_M",
        "bartowski.p-e-w_Qwen3-4B-Instruct-2507-heretic-GGUF.Q4_K_M",
        "bartowski.Meta-Llama-3.1-8B-Instruct-abliterated-GGUF.Q4_K_M"
    ])
    #expect(Set(models.map(\.family)) == [.gemma, .llama, .qwen])

    for model in models {
        let artifact = try #require(model.source?.artifacts.first)
        #expect(model.backend == .llamaCpp)
        #expect(model.quantization?.format.hasPrefix("GGUF ") == true)
        #expect(model.supportsStreaming)
        #expect(model.source?.artifacts.count == 1)
        #expect(artifact.relativePath.hasSuffix(".gguf"))
        #expect(artifact.byteCount != nil)
        #expect((model.minimumRAMGB ?? 0) <= 8)
    }
}
