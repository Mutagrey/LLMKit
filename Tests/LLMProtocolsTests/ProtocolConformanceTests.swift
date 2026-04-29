import LLMCore
import LLMProtocols
import Testing

private struct FakeBackend: ModelBackend {
    let backendKind: BackendKind = .remote

    func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        .available
    }

    func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.capabilities.contains(capability)
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    func unloadModel(_ handle: LoadedModelHandle) async {}

    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.completed(GenerationResult(text: "ok", model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: "ok"))
            continuation.yield(.completed(ChatResult(message: message, model: request.model)))
            continuation.finish()
        }
    }
}

@Test func modelBackendContractExposesBackendNeutralSurface() async throws {
    let descriptor = ModelDescriptor(
        id: "remote-test",
        displayName: "Remote Test",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.completion],
        isRemote: true
    )
    let backend = FakeBackend()

    let availability = await backend.availability(for: descriptor)
    let handle = try await backend.loadModel(descriptor)

    #expect(availability.status == .available)
    #expect(backend.supports(.completion, model: descriptor))
    #expect(handle.id == descriptor.id)
    #expect(handle.backend == descriptor.backend)
}
