import LLMCore
import LLMProtocols

public struct DefaultLanguageGenerationService: LanguageGenerationService {
    private let router: ModelRouter
    private let registry: BackendRegistry
    private let fallback: FallbackCoordinator
    private let safetyPolicy: (any SafetyPolicyEvaluating)?

    public init(
        router: ModelRouter,
        registry: BackendRegistry,
        fallback: FallbackCoordinator = FallbackCoordinator(),
        safetyPolicy: (any SafetyPolicyEvaluating)? = nil
    ) {
        self.router = router
        self.registry = registry
        self.fallback = fallback
        self.safetyPolicy = safetyPolicy
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
                    let safeRequest = try await requestAfterInputSafety(request)
                    let plan = try await router.plan(requirements: safeRequest.requirements)
                    try await stream(safeRequest, using: plan, continuation: continuation)
                } catch let error as SafetyPolicyDenied {
                    continuation.finish(throwing: LLMError.executionFailed(SafetyPolicyBridge.rejectionMessage(for: error)))
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
                lastError = error(for: availability, model: model)
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
                    case .completed(let result):
                        let safeResult = try await resultAfterOutputSafety(result, model: model)
                        continuation.yield(.completed(safeResult))
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
                guard !(error is SafetyPolicyDenied),
                      request.requirements.allowsFallback,
                      fallback.shouldFallback(after: error) else {
                    throw error
                }
            }

            candidate = fallback.nextCandidate(after: model, in: plan)
        }

        throw lastError ?? LLMError.unavailable
    }

    private func requestAfterInputSafety(_ request: GenerationRequest) async throws -> GenerationRequest {
        guard let safetyPolicy else {
            return request
        }
        let decision = await safetyPolicy.evaluateInput(SafetyInputRequest(
            text: request.prompt,
            requirements: request.requirements
        ))
        switch decision.action {
        case .allow:
            return request
        case .modify:
            guard let redactedText = decision.redactedText else {
                return request
            }
            return GenerationRequest(
                prompt: redactedText,
                structuredOutputSchema: request.structuredOutputSchema,
                requirements: request.requirements,
                sessionID: request.sessionID
            )
        case .deny(let reason):
            throw SafetyPolicyDenied(reason: reason)
        }
    }

    private func resultAfterOutputSafety(_ result: GenerationResult, model: ModelDescriptor) async throws -> GenerationResult {
        guard let safetyPolicy else {
            return result
        }
        let decision = await safetyPolicy.evaluateOutput(SafetyOutputRequest(
            text: result.text,
            modelID: model.id
        ))
        switch decision.action {
        case .allow:
            return result
        case .modify:
            guard let redactedText = decision.redactedText else {
                return result
            }
            return GenerationResult(
                text: redactedText,
                model: result.model,
                usage: result.usage,
                finishReason: result.finishReason
            )
        case .deny(let reason):
            throw SafetyPolicyDenied(reason: reason)
        }
    }

    private func error(for availability: BackendAvailability, model: ModelDescriptor) -> LLMError {
        if let failure = availability.failure {
            return failure
        }
        switch availability.status {
        case .requiresInstall:
            return .modelNotInstalled(model.id)
        case .unavailable(let reason):
            return .executionFailed(reason)
        case .requiresNetwork:
            return .executionFailed("Network access is required for the selected model.")
        case .unsupported:
            return .unsupportedCapabilities(requestedCapabilities(for: model))
        case .available:
            return .unavailable
        }
    }

    private func requestedCapabilities(for model: ModelDescriptor) -> Set<ModelCapability> {
        let completionCapabilities: Set<ModelCapability> = [.completion]
        return model.capabilities.intersection(completionCapabilities).isEmpty ? completionCapabilities : model.capabilities
    }
}
