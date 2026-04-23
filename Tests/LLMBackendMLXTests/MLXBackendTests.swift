import LLMBackendMLX
import LLMCore
import LLMProtocols
import Testing

@Test func mlxSupportMatrixIncludesInitialFamilies() {
    #expect(MLXModelSupportMatrix().supports(.qwen))
    #expect(MLXModelSupportMatrix().supports(.gemma))
    #expect(!MLXModelSupportMatrix().supports(.custom("test")))
}

@Test func mlxBackendRequiresRuntimeBeforeLoading() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])

    let unavailable = await MLXBackend().availability(for: descriptor)
    let handle = try await MLXBackend(runtimeAvailable: true).loadModel(descriptor)

    #expect(unavailable.status != .available)
    #expect(handle.backend == .mlx)
}

@Test func mlxBackendRejectsUnsupportedFamilyAndWrongBackend() async throws {
    let unsupportedFamily = ModelDescriptor(id: "custom", displayName: "Custom", family: .custom("test"), backend: .mlx, capabilities: [.completion])
    let wrongBackend = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .qwen, backend: .coreML, capabilities: [.completion])
    let backend = MLXBackend(runtimeAvailable: true)

    #expect(await backend.availability(for: unsupportedFamily).status == .unsupported)
    #expect(await backend.availability(for: wrongBackend).status == .unsupported)
}

@Test func mlxSkeletonStreamsUnavailableUntilImplemented() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])
    let backend = MLXBackend(runtimeAvailable: true)

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected MLX generation skeleton to be unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}
