import LLMCore
import LLMProtocols

public struct DefaultChatService: ChatService {
    private let router: ModelRouter
    private let registry: BackendRegistry

    public init(router: ModelRouter, registry: BackendRegistry) {
        self.router = router
        self.registry = registry
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let model = try await router.route(requirements: request.requirements)
                    guard let backend = await registry.backend(for: model.backend) else {
                        throw LLMError.unavailable
                    }
                    let backendRequest = BackendChatRequest(request: request, model: model, traceID: .generated())
                    for try await event in backend.chat(backendRequest) {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
