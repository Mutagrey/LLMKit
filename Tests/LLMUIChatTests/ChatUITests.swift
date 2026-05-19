import Foundation
import LLMCore
import LLMProtocols
import LLMUIChat
import Testing

private struct StreamingChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.delta("hel"))
            continuation.yield(.delta("lo"))
            continuation.finish()
        }
    }
}

private struct CompletingChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: "done"))
            continuation.yield(.completed(ChatResult(message: message)))
            continuation.finish()
        }
    }
}

private struct FailingChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.executionFailed("chat failed"))
        }
    }
}

private struct ToolEventsChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let invocation = ToolInvocation(
                id: "call_weather_1",
                toolName: "weather",
                arguments: ToolArguments(structuredValues: ["city": .string("Paris")])
            )
            continuation.yield(.toolCallRequested(invocation))
            continuation.yield(.toolCallCompleted(ToolResult(invocationID: invocation.id, content: #"{"forecast":"sunny"}"#)))
            continuation.yield(.completed(ChatResult(
                message: ChatMessage(role: .assistant, content: MessageContent(text: "Sunny in Paris"))
            )))
            continuation.finish()
        }
    }
}

private struct ToolFailureChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let invocation = ToolInvocation(
                id: "call_weather_1",
                toolName: "weather",
                arguments: ToolArguments(structuredValues: ["city": .string("Paris")])
            )
            continuation.yield(.toolCallRequested(invocation))
            continuation.yield(.toolCallCompleted(ToolResult(
                invocationID: invocation.id,
                content: "tool failed",
                isError: true
            )))
            continuation.finish(throwing: LLMError.toolExecutionFailed("tool failed"))
        }
    }
}

private final class RecordingChatService: ChatService, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [ChatRequest] = []
    private var recordedResetSessionIDs: [SessionID] = []

    var requests: [ChatRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    var resetSessionIDs: [SessionID] {
        lock.lock()
        defer { lock.unlock() }
        return recordedResetSessionIDs
    }

    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()

        return AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: "recorded"))
            continuation.yield(.completed(ChatResult(message: message)))
            continuation.finish()
        }
    }

    func resetSession(_ sessionID: SessionID) async {
        recordReset(sessionID)
    }

    private func recordReset(_ sessionID: SessionID) {
        lock.lock()
        recordedResetSessionIDs.append(sessionID)
        lock.unlock()
    }
}

private final class SignatureBox: @unchecked Sendable {
    @MainActor
    var value: String

    @MainActor
    init(_ value: String) {
        self.value = value
    }
}

@MainActor
@Test func chatViewModelAppendsMessages() {
    let viewModel = ChatViewModel()

    viewModel.append(ChatMessage(role: .user, content: MessageContent(text: "hello")))

    #expect(viewModel.messages.count == 1)
}

@MainActor
@Test func chatViewModelSendsMessageThroughService() async {
    let viewModel = ChatViewModel(chatService: StreamingChatService())

    await viewModel.send("hi")

    #expect(viewModel.messages.map(\.role) == [.user, .assistant])
    #expect(viewModel.messages.last?.content.text == "hello")
    #expect(viewModel.streamingText.isEmpty)
    #expect(!viewModel.isStreaming)
}

@MainActor
@Test func chatViewModelAttachesNewRuntimeMetricsToAssistantMessage() async {
    let metric = TelemetryEvent(name: "mlx.generation.completed", metadata: [
        "runtime.generation_time_ms": "200",
        "runtime.tokens_per_second": "18.0"
    ])
    let sequence = RuntimeMetricsSequence(event: metric)
    let viewModel = ChatViewModel(
        chatService: CompletingChatService(),
        runtimeMetricsProvider: { await sequence.snapshot() }
    )

    await viewModel.send("hi")

    guard case .message(let message, let runtimeMetrics)? = viewModel.transcriptItems.last?.content else {
        Issue.record("Expected assistant transcript item with runtime metrics.")
        return
    }

    #expect(message.role == .assistant)
    #expect(runtimeMetrics == [metric])
}

@MainActor
@Test func chatViewModelIgnoresBlankMessages() async {
    let viewModel = ChatViewModel(chatService: StreamingChatService())

    await viewModel.send("   ")

    #expect(viewModel.messages.isEmpty)
    #expect(!viewModel.isStreaming)
}

@MainActor
@Test func chatViewModelTrimsMessageBeforeSending() async {
    let viewModel = ChatViewModel(chatService: CompletingChatService())

    await viewModel.send("  hi  ")

    #expect(viewModel.messages.first?.role == .user)
    #expect(viewModel.messages.first?.content.text == "hi")
    #expect(viewModel.messages.last?.role == .assistant)
    #expect(viewModel.messages.last?.content.text == "done")
}

@MainActor
@Test func chatViewModelSendsNormalizedRequestWithRequirements() async {
    let service = RecordingChatService()
    let requirements = ExecutionRequirements(
        requiredCapabilities: [.chat, .streaming],
        executionMode: .preferOffline,
        preferredLatency: .interactive,
        qualityTier: .fast
    )
    let viewModel = ChatViewModel(chatService: service, requirements: requirements)

    await viewModel.send("  hi  ")
    let requests = service.requests

    #expect(requests.count == 1)
    #expect(requests.first?.messages.map(\.content.text) == ["hi"])
    #expect(requests.first?.requirements == requirements)
}

@MainActor
@Test func chatViewModelPrependsTransientMessagesWithoutPersistingThem() async {
    let service = RecordingChatService()
    let transientMessage = ChatMessage(
        role: .system,
        content: MessageContent(text: "Use the selected demo skills.")
    )
    let viewModel = ChatViewModel(
        chatService: service,
        transientMessagesProvider: {
            [transientMessage]
        },
        transientContextSignatureProvider: {
            "skills:v1"
        }
    )

    await viewModel.send("hi")

    #expect(service.requests.count == 1)
    #expect(service.requests.first?.messages.map(\.role) == [.system, .user])
    #expect(service.requests.first?.messages.map(\.content.text) == ["Use the selected demo skills.", "hi"])
    #expect(viewModel.messages.map(\.role) == [.user, .assistant])
    #expect(viewModel.messages.map(\.content.text) == ["hi", "recorded"])
}

@MainActor
@Test func chatViewModelResetsRuntimeSessionWhenTransientSignatureChanges() async {
    let service = RecordingChatService()
    let sessionID: SessionID = "transient-context-session"
    let signature = SignatureBox("skills:v1")
    let viewModel = ChatViewModel(
        chatService: service,
        sessionID: sessionID,
        transientContextSignatureProvider: {
            signature.value
        }
    )

    await viewModel.send("first")
    signature.value = "skills:v2"
    await viewModel.send("second")

    #expect(service.requests.count == 2)
    #expect(service.resetSessionIDs == [sessionID])
}

@MainActor
@Test func chatViewModelStoresErrorAndStopsStreamingOnServiceFailure() async {
    let viewModel = ChatViewModel(chatService: FailingChatService())

    await viewModel.send("hi")

    #expect(viewModel.messages.map(\.role) == [.user])
    #expect(viewModel.lastError == ChatErrorPresentation(title: "Request Failed", message: "chat failed"))
    #expect(viewModel.streamingText.isEmpty)
    #expect(!viewModel.isStreaming)
}

@MainActor
@Test func chatViewModelWithoutServiceOnlyAppendsUserMessage() async {
    let viewModel = ChatViewModel()

    await viewModel.send("hi")

    #expect(viewModel.messages.map(\.role) == [.user])
    #expect(viewModel.lastErrorMessage == nil)
    #expect(viewModel.streamingText.isEmpty)
    #expect(!viewModel.isStreaming)
}

@MainActor
@Test func chatViewModelPresentsToolLifecycleInTranscript() async {
    let viewModel = ChatViewModel(chatService: ToolEventsChatService())

    await viewModel.send("weather in paris")

    #expect(viewModel.messages.map(\.role) == [.user, .assistant])
    #expect(viewModel.transcriptItems.count == 3)

    guard case .tool(let toolCall)? = viewModel.transcriptItems[safe: 1]?.content else {
        Issue.record("Expected transcript to contain a tool presentation item.")
        return
    }

    #expect(toolCall.id == "call_weather_1")
    #expect(toolCall.toolName == "weather")
    #expect(toolCall.arguments["city"] == .string("Paris"))
    #expect(toolCall.status == .completed(#"{"forecast":"sunny"}"#))
}

@MainActor
@Test func chatViewModelMarksFailedToolInTranscript() async {
    let viewModel = ChatViewModel(chatService: ToolFailureChatService())

    await viewModel.send("weather in paris")

    #expect(viewModel.messages.map(\.role) == [.user])
    #expect(viewModel.lastError == ChatErrorPresentation(title: "Tool Failed", message: "tool failed"))
    #expect(viewModel.transcriptItems.count == 2)

    guard case .tool(let toolCall)? = viewModel.transcriptItems[safe: 1]?.content else {
        Issue.record("Expected transcript to contain a failed tool presentation item.")
        return
    }

    #expect(toolCall.id == "call_weather_1")
    #expect(toolCall.status == .failed("tool failed"))
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private actor RuntimeMetricsSequence {
    private let event: TelemetryEvent
    private var snapshotCount = 0

    init(event: TelemetryEvent) {
        self.event = event
    }

    func snapshot() -> [TelemetryEvent] {
        defer {
            snapshotCount += 1
        }
        return snapshotCount == 0 ? [] : [event]
    }
}
