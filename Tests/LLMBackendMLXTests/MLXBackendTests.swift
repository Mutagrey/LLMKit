import LLMBackendMLX
import LLMCore
import Testing

@Test func mlxSupportMatrixIncludesInitialFamilies() {
    #expect(MLXModelSupportMatrix().supports(.qwen))
    #expect(MLXModelSupportMatrix().supports(.gemma))
}

@Test func mlxBackendRequiresRuntimeBeforeLoading() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])

    let unavailable = await MLXBackend().availability(for: descriptor)
    let handle = try await MLXBackend(runtimeAvailable: true).loadModel(descriptor)

    #expect(unavailable.status != .available)
    #expect(handle.backend == .mlx)
}
