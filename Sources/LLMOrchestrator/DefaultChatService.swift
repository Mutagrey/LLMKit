import LLMCore
import LLMProtocols

public struct DefaultChatService: ChatService {
    private let router: ModelRouter
    private let registry: BackendRegistry
    private let fallback: FallbackCoordinator

    public init(router: ModelRouter, registry: BackendRegistry, fallback: FallbackCoordinator = FallbackCoordinator()) {
        self.router = router
        self.registry = registry
        self.fallback = fallback
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let plan = try await router.plan(requirements: request.requirements)
                    try await stream(request, using: plan, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func stream(
        _ request: ChatRequest,
        using plan: ExecutionPlan,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async throws {
        var candidate = plan.candidates.first
        var lastError: Error?

        while let model = candidate {
            guard let backend = await registry.backend(for: model.backend) else {
                lastError = LLMError.unavailable
                candidate = fallback.nextCandidate(after: model, in: plan)
                continue
            }

            let backendRequest = BackendChatRequest(request: request, model: model, traceID: .generated())
            do {
                var shouldTryNextCandidate = false
                for try await event in backend.chat(backendRequest) {
                    switch event {
                    case .failed(let error):
                        lastError = error
                        shouldTryNextCandidate = true
                    case .completed:
                        continuation.yield(event)
                        continuation.finish()
                        return
                    case .started, .delta, .toolCallRequested, .toolCallCompleted:
                        continuation.yield(event)
                    }
                    if shouldTryNextCandidate {
                        break
                    }
                }
            } catch {
                lastError = error
            }

            candidate = fallback.nextCandidate(after: model, in: plan)
        }

        throw lastError ?? LLMError.unavailable
    }
}
