import Foundation
import LLMBackendMLX
import LLMCore
import LLMModelLifecycle
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
    let requiresInstall = await MLXBackend(
        runtimeAvailable: true,
        modelRootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    ).availability(for: descriptor)

    #expect(unavailable.status != .available)
    #expect(requiresInstall.status == .requiresInstall)
}

@Test func mlxBackendRejectsUnsupportedFamilyAndWrongBackend() async throws {
    let unsupportedFamily = ModelDescriptor(id: "custom", displayName: "Custom", family: .custom("test"), backend: .mlx, capabilities: [.completion])
    let wrongBackend = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .qwen, backend: .coreML, capabilities: [.completion])
    let backend = MLXBackend(runtimeAvailable: true)

    #expect(await backend.availability(for: unsupportedFamily).status == .unsupported)
    #expect(await backend.availability(for: wrongBackend).status == .unsupported)
}

@Test func mlxBackendStreamsUnavailableWhenRuntimeIsNotConfigured() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])
    let backend = MLXBackend()

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected MLX generation skeleton to be unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func mlxBackendReportsAvailableWhenModelDirectoryExists() async throws {
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitMLXTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen",
        displayName: "Qwen",
        family: .qwen,
        backend: .mlx,
        capabilities: [.completion]
    )
    let modelDirectory = ModelArtifactLocationResolver(rootDirectory: rootDirectory)
        .modelDirectory(for: descriptor.id)
    try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: modelDirectory.appendingPathComponent("config.json"))

    let availability = await MLXBackend(
        runtimeAvailable: true,
        modelRootDirectory: rootDirectory
    ).availability(for: descriptor)

    #expect(availability.status == .available)
}
