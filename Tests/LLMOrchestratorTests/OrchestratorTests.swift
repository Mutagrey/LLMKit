import LLMCore
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols
import Testing

private struct StreamingBackend: ModelBackend {
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
            continuation.yield(.started(request.model))
            continuation.yield(.delta("hello"))
            continuation.yield(.completed(GenerationResult(text: "hello", model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: "hello"))
            continuation.yield(.completed(ChatResult(message: message, model: request.model)))
            continuation.finish()
        }
    }
}

@Test func executionPlannerFiltersOfflineOnlyRequests() {
    let local = ModelDescriptor(id: "local", displayName: "Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let requirements = ExecutionRequirements(requiredCapabilities: [.completion], executionMode: .offlineOnly)

    let plan = ExecutionPlanner().plan(models: [remote, local], requirements: requirements)

    #expect(plan.candidates.map(\.id) == ["local"])
}

@Test func defaultGenerationServiceRoutesToBackend() async throws {
    let descriptor = ModelDescriptor(
        id: "remote",
        displayName: "Remote",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.completion],
        isRemote: true
    )
    let catalog = DefaultModelCatalog(models: [descriptor])
    let registry = BackendRegistry(backends: [StreamingBackend()])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)

    let result = try await service.generate(GenerationRequest(prompt: "hi", requirements: ExecutionRequirements(requiredCapabilities: [.completion])))

    #expect(result.text == "hello")
}
