import LLMCore
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols
import Testing

private struct StreamingBackend: ModelBackend {
    let backendKind: BackendKind
    let responseText: String

    init(backendKind: BackendKind = .remote, responseText: String = "hello") {
        self.backendKind = backendKind
        self.responseText = responseText
    }

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
            continuation.yield(.delta(responseText))
            continuation.yield(.completed(GenerationResult(text: responseText, model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: responseText))
            continuation.yield(.completed(ChatResult(message: message, model: request.model)))
            continuation.finish()
        }
    }
}

private struct FailingBackend: ModelBackend {
    let backendKind: BackendKind

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
            continuation.yield(.failed(.executionFailed("backend failed")))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed(.executionFailed("backend failed")))
            continuation.finish()
        }
    }
}

private struct ThrowingBackend: ModelBackend {
    let backendKind: BackendKind

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
            continuation.finish(throwing: LLMError.executionFailed("stream threw"))
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.executionFailed("stream threw"))
        }
    }
}

private struct UnavailableBackend: ModelBackend {
    let backendKind: BackendKind

    func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        BackendAvailability(status: .unavailable(reason: "test unavailable"))
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
            continuation.yield(.completed(GenerationResult(text: "should not execute", model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: "should not execute"))
            continuation.yield(.completed(ChatResult(message: message, model: request.model)))
            continuation.finish()
        }
    }
}

private struct CancellingBackend: ModelBackend {
    let backendKind: BackendKind

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
            continuation.yield(.failed(.cancelled))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed(.cancelled))
            continuation.finish()
        }
    }
}

private final class ToolLoopBackend: ModelBackend, @unchecked Sendable {
    let backendKind: BackendKind
    private let state = State()

    init(backendKind: BackendKind = .remote) {
        self.backendKind = backendKind
    }

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
            continuation.yield(.completed(GenerationResult(text: "unused", model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let round = await state.record(request)

                if round == 0 {
                    continuation.yield(.toolCallRequested(ToolInvocation(
                        id: "call_weather_1",
                        toolName: "weather",
                        arguments: ToolArguments(structuredValues: ["city": .string("Paris")])
                    )))
                    continuation.yield(.completed(ChatResult(
                        message: ChatMessage(role: .assistant, content: MessageContent(text: "")),
                        model: request.model,
                        finishReason: .toolCall
                    )))
                } else {
                    continuation.yield(.completed(ChatResult(
                        message: ChatMessage(role: .assistant, content: MessageContent(text: "Sunny in Paris")),
                        model: request.model
                    )))
                }
                continuation.finish()
            }
        }
    }

    func capturedRequests() async -> [BackendChatRequest] {
        await state.snapshot()
    }

    private actor State {
        private var requests: [BackendChatRequest] = []

        func record(_ request: BackendChatRequest) -> Int {
            let round = requests.count
            requests.append(request)
            return round
        }

        func snapshot() -> [BackendChatRequest] {
            requests
        }
    }
}

private actor RecordingToolService: ToolService {
    private let definitions: [ToolDefinition]
    private let resultText: String
    private var invocations: [ToolInvocation] = []

    init(definitions: [ToolDefinition], resultText: String) {
        self.definitions = definitions
        self.resultText = resultText
    }

    func availableTools() async -> [ToolDefinition] {
        definitions
    }

    func execute(_ invocation: ToolInvocation) async throws -> ToolResult {
        invocations.append(invocation)
        return ToolResult(invocationID: invocation.id, content: resultText)
    }

    func capturedInvocations() -> [ToolInvocation] {
        invocations
    }
}

private actor FailingToolService: ToolService {
    private let definitions: [ToolDefinition]

    init(definitions: [ToolDefinition]) {
        self.definitions = definitions
    }

    func availableTools() async -> [ToolDefinition] {
        definitions
    }

    func execute(_ invocation: ToolInvocation) async throws -> ToolResult {
        throw LLMError.toolExecutionFailed("tool failed")
    }
}

@Test func executionPlannerFiltersOfflineOnlyRequests() {
    let local = ModelDescriptor(id: "local", displayName: "Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let requirements = ExecutionRequirements(requiredCapabilities: [.completion], executionMode: .offlineOnly)

    let plan = ExecutionPlanner().plan(models: [remote, local], requirements: requirements)

    #expect(plan.candidates.map(\.id) == ["local"])
}

@Test func executionPlannerRequiresAllRequestedCapabilities() {
    let completionOnly = ModelDescriptor(
        id: "completion-only",
        displayName: "Completion Only",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let chatAndTools = ModelDescriptor(
        id: "chat-tools",
        displayName: "Chat Tools",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.chat, .toolCalling],
        isRemote: true
    )
    let requirements = ExecutionRequirements(requiredCapabilities: [.chat, .toolCalling])

    let plan = ExecutionPlanner().plan(models: [completionOnly, chatAndTools], requirements: requirements)

    #expect(plan.candidates.map(\.id) == ["chat-tools"])
}

@Test func executionPlannerPrefersOfflineModelsWhenRequested() {
    let local = ModelDescriptor(id: "local", displayName: "Z Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "A Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let requirements = ExecutionRequirements(requiredCapabilities: [.completion], executionMode: .preferOffline)

    let plan = ExecutionPlanner().plan(models: [remote, local], requirements: requirements)

    #expect(plan.candidates.map(\.id) == ["local", "remote"])
}

@Test func modelRouterThrowsUnsupportedCapabilitiesWhenNoCandidateMatches() async throws {
    let descriptor = ModelDescriptor(
        id: "completion-only",
        displayName: "Completion Only",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let catalog = DefaultModelCatalog(models: [descriptor])
    let router = ModelRouter(catalog: catalog)
    let requirements = ExecutionRequirements(requiredCapabilities: [.embeddings])

    do {
        _ = try await router.plan(requirements: requirements)
        Issue.record("Expected router to reject unsupported capabilities.")
    } catch let error as LLMError {
        #expect(error == .unsupportedCapabilities([.embeddings]))
    }
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

@Test func generationServiceFallsBackToNextCandidate() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        FailingBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "fallback")
    ])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)

    let result = try await service.generate(GenerationRequest(prompt: "hi", requirements: ExecutionRequirements(requiredCapabilities: [.completion])))

    #expect(result.text == "fallback")
    #expect(result.model?.id == "remote")
}

@Test func generationServiceSkipsMissingBackend() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [StreamingBackend(backendKind: .remote, responseText: "remote")])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)

    let result = try await service.generate(GenerationRequest(prompt: "hi", requirements: ExecutionRequirements(requiredCapabilities: [.completion])))

    #expect(result.text == "remote")
    #expect(result.model?.id == "remote")
}

@Test func generationServiceSkipsUnavailableBackend() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        UnavailableBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "available")
    ])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)

    let result = try await service.generate(GenerationRequest(prompt: "hi", requirements: ExecutionRequirements(requiredCapabilities: [.completion])))

    #expect(result.text == "available")
    #expect(result.model?.id == "remote")
}

@Test func generationServiceFallsBackAfterThrownStreamError() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        ThrowingBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "recovered")
    ])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)

    let result = try await service.generate(GenerationRequest(prompt: "hi", requirements: ExecutionRequirements(requiredCapabilities: [.completion])))

    #expect(result.text == "recovered")
    #expect(result.model?.id == "remote")
}

@Test func generationServiceFallsBackFromUnavailablePreferredModel() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [local, remote])
    let registry = BackendRegistry(backends: [
        StreamingBackend(backendKind: .coreML, responseText: "local fallback"),
        UnavailableBackend(backendKind: .remote)
    ])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)
    let requirements = ExecutionRequirements(requiredCapabilities: [.completion], preferredModel: "remote")

    let result = try await service.generate(GenerationRequest(prompt: "hi", requirements: requirements))

    #expect(result.text == "local fallback")
    #expect(result.model?.id == "local")
}

@Test func generationServiceDoesNotFallbackAfterCancellation() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        CancellingBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "should not execute")
    ])
    let service = DefaultLanguageGenerationService(router: ModelRouter(catalog: catalog), registry: registry)

    do {
        _ = try await service.generate(GenerationRequest(prompt: "hi", requirements: ExecutionRequirements(requiredCapabilities: [.completion])))
        Issue.record("Expected cancellation to stop fallback.")
    } catch {
        #expect(error as? LLMError == .cancelled)
    }
}

@Test func routerPrioritizesPreferredModelInPlan() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let router = ModelRouter(catalog: catalog)
    let requirements = ExecutionRequirements(requiredCapabilities: [.completion], preferredModel: "remote")

    let plan = try await router.plan(requirements: requirements)

    #expect(plan.candidates.map(\.id) == ["remote", "local"])
}

@Test func chatServiceFallsBackToNextCandidate() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.chat])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.chat], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        FailingBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "chat fallback")
    ])
    let service = DefaultChatService(router: ModelRouter(catalog: catalog), registry: registry)
    let userMessage = ChatMessage(role: .user, content: MessageContent(text: "hi"))
    let request = ChatRequest(messages: [userMessage], requirements: ExecutionRequirements(requiredCapabilities: [.chat]))

    var completed: ChatResult?
    for try await event in service.send(request) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    #expect(completed?.message.content.text == "chat fallback")
    #expect(completed?.model?.id == "remote")
}

@Test func chatServiceFallsBackAfterThrownStreamError() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.chat])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.chat], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        ThrowingBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "chat recovered")
    ])
    let service = DefaultChatService(router: ModelRouter(catalog: catalog), registry: registry)
    let userMessage = ChatMessage(role: .user, content: MessageContent(text: "hi"))
    let request = ChatRequest(messages: [userMessage], requirements: ExecutionRequirements(requiredCapabilities: [.chat]))

    var completed: ChatResult?
    for try await event in service.send(request) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    #expect(completed?.message.content.text == "chat recovered")
    #expect(completed?.model?.id == "remote")
}

@Test func chatServiceDoesNotFallbackAfterCancellation() async throws {
    let local = ModelDescriptor(id: "local", displayName: "A Local", family: .custom("test"), backend: .coreML, capabilities: [.chat])
    let remote = ModelDescriptor(id: "remote", displayName: "Z Remote", family: .custom("test"), backend: .remote, capabilities: [.chat], isRemote: true)
    let catalog = DefaultModelCatalog(models: [remote, local])
    let registry = BackendRegistry(backends: [
        CancellingBackend(backendKind: .coreML),
        StreamingBackend(backendKind: .remote, responseText: "should not execute")
    ])
    let service = DefaultChatService(router: ModelRouter(catalog: catalog), registry: registry)
    let userMessage = ChatMessage(role: .user, content: MessageContent(text: "hi"))
    let request = ChatRequest(messages: [userMessage], requirements: ExecutionRequirements(requiredCapabilities: [.chat]))

    do {
        for try await _ in service.send(request) {}
        Issue.record("Expected cancellation to stop chat fallback.")
    } catch {
        #expect(error as? LLMError == .cancelled)
    }
}

@Test func chatServiceExecutesToolRoundTripOnSameModel() async throws {
    let descriptor = ModelDescriptor(
        id: "remote-tools",
        displayName: "Remote Tools",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.chat, .toolCalling],
        isRemote: true
    )
    let catalog = DefaultModelCatalog(models: [descriptor])
    let backend = ToolLoopBackend()
    let tool = ToolDefinition(
        name: "weather",
        description: "Lookup weather",
        schema: ToolSchema(requiredArguments: ["city"])
    )
    let toolService = RecordingToolService(definitions: [tool], resultText: "sunny")
    let service = DefaultChatService(
        router: ModelRouter(catalog: catalog),
        registry: BackendRegistry(backends: [backend]),
        tools: toolService
    )
    let request = ChatRequest(
        messages: [ChatMessage(role: .user, content: MessageContent(text: "Weather in Paris?"))],
        requirements: ExecutionRequirements(requiredCapabilities: [.chat, .toolCalling])
    )

    var requested: [ToolInvocation] = []
    var completedResults: [ToolResult] = []
    var completed: ChatResult?
    for try await event in service.send(request) {
        switch event {
        case .toolCallRequested(let invocation):
            requested.append(invocation)
        case .toolCallCompleted(let result):
            completedResults.append(result)
        case .completed(let result):
            completed = result
        case .started, .delta, .failed:
            break
        }
    }

    let capturedRequests = await backend.capturedRequests()
    let capturedInvocations = await toolService.capturedInvocations()

    #expect(requested.count == 1)
    #expect(requested.first?.toolName == "weather")
    #expect(requested.first?.arguments["city"] == .string("Paris"))
    #expect(completedResults.count == 1)
    #expect(completedResults.first?.content == "sunny")
    #expect(completed?.message.content.text == "Sunny in Paris")
    #expect(capturedInvocations.count == 1)
    #expect(capturedRequests.count == 2)
    #expect(capturedRequests.first?.request.tools == [tool])
    #expect(capturedRequests.last?.request.messages.count == 2)
    #expect(capturedRequests.last?.request.messages.last?.role == .tool)
    #expect(capturedRequests.last?.request.messages.last?.content.text == "sunny")
    #expect(capturedRequests.last?.request.messages.last?.toolCallReference == ToolCallReference(id: "call_weather_1", toolName: "weather"))
}

@Test func chatServiceDoesNotFallbackWhenToolExecutionFails() async throws {
    let first = ModelDescriptor(
        id: "a-tools",
        displayName: "A Tools",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.chat, .toolCalling]
    )
    let fallbackModel = ModelDescriptor(
        id: "z-fallback",
        displayName: "Z Fallback",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.chat],
        isRemote: true
    )
    let catalog = DefaultModelCatalog(models: [fallbackModel, first])
    let backend = ToolLoopBackend(backendKind: .coreML)
    let fallbackBackend = StreamingBackend(backendKind: .remote, responseText: "should not execute")
    let tool = ToolDefinition(name: "weather", description: "Lookup weather")
    let service = DefaultChatService(
        router: ModelRouter(catalog: catalog),
        registry: BackendRegistry(backends: [backend, fallbackBackend]),
        tools: FailingToolService(definitions: [tool])
    )
    let request = ChatRequest(
        messages: [ChatMessage(role: .user, content: MessageContent(text: "Weather in Paris?"))],
        requirements: ExecutionRequirements(requiredCapabilities: [.chat, .toolCalling])
    )

    do {
        for try await _ in service.send(request) {}
        Issue.record("Expected tool execution failure to stop chat round-trip.")
    } catch {
        #expect(error as? LLMError == .toolExecutionFailed("tool failed"))
    }

    let capturedRequests = await backend.capturedRequests()
    #expect(capturedRequests.count == 1)
}
