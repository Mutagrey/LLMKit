import LLMBackendFoundationModels
import LLMCore
import Testing

@Test func foundationModelsBackendReportsKind() {
    #expect(FoundationModelsBackend().backendKind == .foundationModels)
}

@Test func foundationModelsBackendReportsConfiguredAvailability() async throws {
    let descriptor = ModelDescriptor(
        id: "foundation-model",
        displayName: "Foundation Model",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.completion]
    )
    let unavailable = await FoundationModelsBackend().availability(for: descriptor)
    let availableBackend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true))
    let handle = try await availableBackend.loadModel(descriptor)

    #expect(unavailable.status != .available)
    #expect(await availableBackend.availability(for: descriptor).status == .available)
    #expect(handle.backend == .foundationModels)
}
