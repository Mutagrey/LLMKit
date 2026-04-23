import LLMBackendFoundationModels
import LLMCore
import LLMProtocols
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

@Test func foundationModelsBackendRejectsWrongBackendDescriptor() async throws {
    let descriptor = ModelDescriptor(id: "remote", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let backend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true))

    let availability = await backend.availability(for: descriptor)

    #expect(availability.status == .unsupported)
    do {
        _ = try await backend.loadModel(descriptor)
        Issue.record("Expected Foundation Models backend to reject non-foundation descriptor.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func foundationModelsSkeletonStreamsUnavailableUntilImplemented() async throws {
    let descriptor = ModelDescriptor(id: "foundation", displayName: "Foundation", family: .appleFoundation, backend: .foundationModels, capabilities: [.completion])
    let backend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true))

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected Foundation Models generation skeleton to be unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}
