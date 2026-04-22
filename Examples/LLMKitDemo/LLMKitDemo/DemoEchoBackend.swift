import LLMCore
import LLMProtocols

struct DemoEchoBackend: ModelBackend {
    let backendKind: BackendKind = .custom("demo")

    func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        descriptor.backend == backendKind ? .available : .unsupported
    }

    func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind && model.capabilities.contains(capability)
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    func unloadModel(_ handle: LoadedModelHandle) async {}

    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started(request.model))
            continuation.yield(.delta("Demo response: "))
            continuation.yield(.delta(request.request.prompt))
            continuation.yield(.completed(GenerationResult(text: "Demo response: \(request.request.prompt)", model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let latest = request.request.messages.last?.content.text ?? "Hello"
            let response = "Demo backend routed this message through LLMKit: \(latest)"
            continuation.yield(.started(request.model))
            continuation.yield(.delta(response))
            let message = ChatMessage(role: .assistant, content: MessageContent(text: response))
            continuation.yield(.completed(ChatResult(message: message, model: request.model)))
            continuation.finish()
        }
    }
}
