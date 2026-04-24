import LLMCore
import LLMProtocols

public struct DefaultLanguageGenerationService: LanguageGenerationService {
    private let router: ModelRouter
    private let registry: BackendRegistry
    private let fallback: FallbackCoordinator

    public init(router: ModelRouter, registry: BackendRegistry, fallback: FallbackCoordinator = FallbackCoordinator()) {
        self.router = router
        self.registry = registry
        self.fallback = fallback
    }

    public func generate(_ request: GenerationRequest) async throws -> GenerationResult {
        var accumulator = StreamedTextAccumulator()
        for try await event in stream(request) {
            switch event {
            case .delta(let text):
                accumulator.append(text)
            case .completed(let result):
                return result
            case .failed(let error):
                throw error
            case .started:
                break
            }
        }
        return GenerationResult(text: accumulator.text)
    }

    public func stream(_ request: GenerationRequest) -> AsyncThrowingStream<GenerationEvent, Error> {
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
        _ request: GenerationRequest,
        using plan: ExecutionPlan,
        continuation: AsyncThrowingStream<GenerationEvent, Error>.Continuation
    ) async throws {
        var candidate = plan.candidates.first
        var lastError: Error?

        while let model = candidate {
            guard let backend = await registry.backend(for: model.backend) else {
                lastError = LLMError.unavailable
                guard request.requirements.allowsFallback else {
                    throw lastError ?? LLMError.unavailable
                }
                candidate = fallback.nextCandidate(after: model, in: plan)
                continue
            }
            let availability = await backend.availability(for: model)
            guard availability.status == .available else {
                lastError = LLMError.unavailable
                guard request.requirements.allowsFallback else {
                    throw lastError ?? LLMError.unavailable
                }
                candidate = fallback.nextCandidate(after: model, in: plan)
                continue
            }

            let backendRequest = BackendGenerationRequest(request: request, model: model, traceID: .generated())
            do {
                var shouldTryNextCandidate = false
                for try await event in backend.generate(backendRequest) {
                    switch event {
                    case .failed(let error):
                        lastError = error
                        guard request.requirements.allowsFallback, fallback.shouldFallback(after: error) else {
                            throw error
                        }
                        shouldTryNextCandidate = true
                    case .completed:
                        continuation.yield(event)
                        continuation.finish()
                        return
                    case .started, .delta:
                        continuation.yield(event)
                    }
                    if shouldTryNextCandidate {
                        break
                    }
                }
            } catch {
                lastError = error
                guard request.requirements.allowsFallback, fallback.shouldFallback(after: error) else {
                    throw error
                }
            }

            candidate = fallback.nextCandidate(after: model, in: plan)
        }

        throw lastError ?? LLMError.unavailable
    }
}
