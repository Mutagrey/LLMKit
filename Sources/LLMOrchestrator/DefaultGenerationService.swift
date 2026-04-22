import LLMCore
import LLMProtocols

public struct DefaultLanguageGenerationService: LanguageGenerationService {
    private let router: ModelRouter
    private let registry: BackendRegistry

    public init(router: ModelRouter, registry: BackendRegistry) {
        self.router = router
        self.registry = registry
    }

    public func generate(_ request: GenerationRequest) async throws -> GenerationResult {
        var accumulated = ""
        for try await event in stream(request) {
            switch event {
            case .delta(let text):
                accumulated += text
            case .completed(let result):
                return result
            case .failed(let error):
                throw error
            case .started:
                break
            }
        }
        return GenerationResult(text: accumulated)
    }

    public func stream(_ request: GenerationRequest) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let model = try await router.route(requirements: request.requirements)
                    guard let backend = await registry.backend(for: model.backend) else {
                        throw LLMError.unavailable
                    }
                    let backendRequest = BackendGenerationRequest(request: request, model: model, traceID: .generated())
                    for try await event in backend.generate(backendRequest) {
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
