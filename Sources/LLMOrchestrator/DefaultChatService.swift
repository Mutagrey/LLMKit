import LLMCore
import LLMProtocols

public struct DefaultChatService: ChatService {
    private let router: ModelRouter
    private let registry: BackendRegistry
    private let fallback: FallbackCoordinator
    private let tools: (any ToolService)?
    private let maximumToolRoundTrips: Int
    private let safetyPolicy: (any SafetyPolicyEvaluating)?

    public init(
        router: ModelRouter,
        registry: BackendRegistry,
        fallback: FallbackCoordinator = FallbackCoordinator(),
        tools: (any ToolService)? = nil,
        maximumToolRoundTrips: Int = 8,
        safetyPolicy: (any SafetyPolicyEvaluating)? = nil
    ) {
        self.router = router
        self.registry = registry
        self.fallback = fallback
        self.tools = tools
        self.maximumToolRoundTrips = maximumToolRoundTrips
        self.safetyPolicy = safetyPolicy
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let effectiveRequest = try await requestAfterInputSafety(
                        await requestWithResolvedTools(request)
                    )
                    let plan = try await router.plan(requirements: effectiveRequest.requirements)
                    try await stream(effectiveRequest, using: plan, continuation: continuation)
                } catch let error as SafetyPolicyDenied {
                    continuation.finish(throwing: LLMError.executionFailed(SafetyPolicyBridge.rejectionMessage(for: error)))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func resetSession(_ sessionID: SessionID) async {
        let backends = await registry.allBackends()
        for backend in backends {
            guard let resettable = backend as? any BackendChatSessionResetting else {
                continue
            }
            await resettable.resetChatSessions(sessionID: sessionID)
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

            var didResetCurrentAttempt = false
            do {
                var shouldTryNextCandidate = false
                var currentRequest = request
                var toolRoundTrips = 0

                while true {
                    let backendRequest = BackendChatRequest(request: currentRequest, model: model, traceID: .generated())
                    var pendingToolCalls: [ToolInvocation] = []
                    var completedResult: ChatResult?

                    for try await event in backend.chat(backendRequest) {
                        switch event {
                        case .failed(let error):
                            lastError = error
                            await resetChatSessionIfNeeded(backend: backend, model: model, sessionID: currentRequest.sessionID)
                            didResetCurrentAttempt = true
                            guard shouldAttemptFallback(after: error, requirements: request.requirements) else {
                                throw error
                            }
                            shouldTryNextCandidate = true
                        case .completed(let result):
                            completedResult = result
                        case .toolCallRequested(let invocation):
                            pendingToolCalls.append(invocation)
                            continuation.yield(event)
                        case .started, .delta, .toolCallCompleted:
                            continuation.yield(event)
                        }

                        if shouldTryNextCandidate {
                            break
                        }
                    }

                    if shouldTryNextCandidate {
                        break
                    }

                    guard let completedResult else {
                        await resetChatSessionIfNeeded(backend: backend, model: model, sessionID: currentRequest.sessionID)
                        didResetCurrentAttempt = true
                        throw LLMError.executionFailed("Chat stream finished without completion.")
                    }

                    guard shouldContinueToolRoundTrip(for: completedResult, toolCalls: pendingToolCalls) else {
                        let safeResult = try await resultAfterOutputSafety(completedResult, model: model)
                        continuation.yield(.completed(safeResult))
                        continuation.finish()
                        return
                    }

                    toolRoundTrips += 1
                    guard toolRoundTrips <= maximumToolRoundTrips else {
                        throw LLMError.toolExecutionFailed("Exceeded maximum tool round trips.")
                    }

                    currentRequest = try await requestAfterExecutingTools(
                        from: currentRequest,
                        assistantResult: completedResult,
                        toolCalls: pendingToolCalls,
                        continuation: continuation
                    )
                }
            } catch {
                lastError = error
                if !didResetCurrentAttempt {
                    await resetChatSessionIfNeeded(backend: backend, model: model, sessionID: request.sessionID)
                }
                guard shouldAttemptFallback(after: error, requirements: request.requirements) else {
                    throw error
                }
            }

            candidate = fallback.nextCandidate(after: model, in: plan)
        }

        throw lastError ?? LLMError.unavailable
    }

    private func requestWithResolvedTools(_ request: ChatRequest) async -> ChatRequest {
        guard request.tools.isEmpty, let tools else {
            return request
        }
        let availableTools = await tools.availableTools()
        guard !availableTools.isEmpty else {
            return request
        }
        return ChatRequest(
            messages: request.messages,
            requirements: request.requirements,
            sessionID: request.sessionID,
            tools: availableTools
        )
    }

    private func requestAfterInputSafety(_ request: ChatRequest) async throws -> ChatRequest {
        guard let safetyPolicy else {
            return request
        }
        let inputText = request.messages.map(\.content.text).joined(separator: "\n")
        let decision = await safetyPolicy.evaluateInput(SafetyInputRequest(
            text: inputText,
            requirements: request.requirements
        ))
        switch decision.action {
        case .allow:
            return request
        case .modify:
            guard let redactedText = decision.redactedText else {
                return request
            }
            return requestReplacingLastText(request, with: redactedText)
        case .deny(let reason):
            throw SafetyPolicyDenied(reason: reason)
        }
    }

    private func requestReplacingLastText(_ request: ChatRequest, with text: String) -> ChatRequest {
        guard let index = request.messages.lastIndex(where: { $0.role == .user }) ?? request.messages.indices.last else {
            return request
        }
        var messages = request.messages
        let original = messages[index]
        messages[index] = ChatMessage(
            id: original.id,
            role: original.role,
            content: MessageContent(text: text, attachments: original.content.attachments),
            createdAt: original.createdAt,
            toolCallReference: original.toolCallReference
        )
        return ChatRequest(
            messages: messages,
            requirements: request.requirements,
            sessionID: request.sessionID,
            tools: request.tools
        )
    }

    private func resultAfterOutputSafety(_ result: ChatResult, model: ModelDescriptor) async throws -> ChatResult {
        guard let safetyPolicy else {
            return result
        }
        let decision = await safetyPolicy.evaluateOutput(SafetyOutputRequest(
            text: result.message.content.text,
            modelID: model.id
        ))
        switch decision.action {
        case .allow:
            return result
        case .modify:
            guard let redactedText = decision.redactedText else {
                return result
            }
            let message = ChatMessage(
                id: result.message.id,
                role: result.message.role,
                content: MessageContent(text: redactedText, attachments: result.message.content.attachments),
                createdAt: result.message.createdAt,
                toolCallReference: result.message.toolCallReference
            )
            return ChatResult(
                message: message,
                model: result.model,
                usage: result.usage,
                finishReason: result.finishReason
            )
        case .deny(let reason):
            throw SafetyPolicyDenied(reason: reason)
        }
    }

    private func shouldContinueToolRoundTrip(for result: ChatResult, toolCalls: [ToolInvocation]) -> Bool {
        tools != nil && !toolCalls.isEmpty
    }

    private func requestAfterExecutingTools(
        from request: ChatRequest,
        assistantResult: ChatResult,
        toolCalls: [ToolInvocation],
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async throws -> ChatRequest {
        guard let tools else {
            return request
        }

        var messages = request.messages
        if shouldPersistAssistantMessage(assistantResult.message) {
            messages.append(assistantResult.message)
        }

        for invocation in toolCalls {
            let result: ToolResult
            do {
                result = try await tools.execute(invocation)
            } catch let error as LLMError {
                let mappedError = mapToolExecutionError(error)
                if case .cancelled = mappedError {
                    throw mappedError
                }
                continuation.yield(.toolCallCompleted(errorResult(for: invocation, error: mappedError)))
                throw mappedError
            } catch {
                let mappedError = LLMError.toolExecutionFailed(error.localizedDescription)
                continuation.yield(.toolCallCompleted(errorResult(for: invocation, error: mappedError)))
                throw mappedError
            }

            continuation.yield(.toolCallCompleted(result))
            messages.append(ChatMessage(
                role: .tool,
                content: MessageContent(text: result.content),
                toolCallReference: ToolCallReference(id: invocation.id, toolName: invocation.toolName)
            ))
        }

        return ChatRequest(
            messages: messages,
            requirements: request.requirements,
            sessionID: request.sessionID,
            tools: request.tools
        )
    }

    private func shouldPersistAssistantMessage(_ message: ChatMessage) -> Bool {
        !message.content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !message.content.attachments.isEmpty
            || message.toolCallReference != nil
    }

    private func mapToolExecutionError(_ error: LLMError) -> LLMError {
        switch error {
        case .toolExecutionFailed:
            return error
        case .executionFailed(let message):
            return .toolExecutionFailed(message)
        case .cancelled:
            return error
        default:
            return .toolExecutionFailed(String(describing: error))
        }
    }

    private func errorResult(for invocation: ToolInvocation, error: LLMError) -> ToolResult {
        let message: String
        switch error {
        case .toolExecutionFailed(let value), .executionFailed(let value):
            message = value
        case .cancelled:
            message = "cancelled"
        default:
            message = String(describing: error)
        }
        return ToolResult(invocationID: invocation.id, content: message, isError: true)
    }

    private func shouldAttemptFallback(after error: Error, requirements: ExecutionRequirements) -> Bool {
        if error is SafetyPolicyDenied {
            return false
        }
        guard requirements.allowsFallback else {
            return false
        }
        if let llmError = error as? LLMError, llmError == .cancelled {
            return false
        }
        if case .toolExecutionFailed = error as? LLMError {
            return false
        }
        return fallback.shouldFallback(after: error)
    }

    private func resetChatSessionIfNeeded(
        backend: any ModelBackend,
        model: ModelDescriptor,
        sessionID: SessionID?
    ) async {
        guard let sessionID, let resettable = backend as? any BackendChatSessionResetting else {
            return
        }
        await resettable.resetChatSession(modelID: model.id, sessionID: sessionID)
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
            return .unsupportedCapabilities([.chat])
        case .available:
            return .unavailable
        }
    }
}
