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

    var requests: [ChatRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
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
