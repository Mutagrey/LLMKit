import LLMCore
import LLMProtocols

public struct DefaultChatService: ChatService {
    private let router: ModelRouter
    private let registry: BackendRegistry
    private let fallback: FallbackCoordinator
    private let tools: (any ToolService)?
    private let maximumToolRoundTrips: Int

    public init(
        router: ModelRouter,
        registry: BackendRegistry,
        fallback: FallbackCoordinator = FallbackCoordinator(),
        tools: (any ToolService)? = nil,
        maximumToolRoundTrips: Int = 8
    ) {
        self.router = router
        self.registry = registry
        self.fallback = fallback
        self.tools = tools
        self.maximumToolRoundTrips = maximumToolRoundTrips
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let effectiveRequest = await requestWithResolvedTools(request)
                    let plan = try await router.plan(requirements: effectiveRequest.requirements)
                    try await stream(effectiveRequest, using: plan, continuation: continuation)
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
            let availability = await backend.availability(for: model)
            guard availability.status == .available else {
                lastError = LLMError.unavailable
                candidate = fallback.nextCandidate(after: model, in: plan)
                continue
            }

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
                            guard shouldAttemptFallback(after: error) else {
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
                        throw LLMError.executionFailed("Chat stream finished without completion.")
                    }

                    guard shouldContinueToolRoundTrip(for: completedResult, toolCalls: pendingToolCalls) else {
                        continuation.yield(.completed(completedResult))
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
                guard shouldAttemptFallback(after: error) else {
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
                switch error {
                case .toolExecutionFailed(let message):
                    throw LLMError.toolExecutionFailed(message)
                case .executionFailed(let message):
                    throw LLMError.toolExecutionFailed(message)
                case .cancelled:
                    throw error
                default:
                    throw LLMError.toolExecutionFailed(String(describing: error))
                }
            } catch {
                throw LLMError.toolExecutionFailed(error.localizedDescription)
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

    private func shouldAttemptFallback(after error: Error) -> Bool {
        if case .toolExecutionFailed = error as? LLMError {
            return false
        }
        return fallback.shouldFallback(after: error)
    }
}
