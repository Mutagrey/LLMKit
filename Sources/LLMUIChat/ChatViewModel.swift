import LLMCore
import LLMProtocols
import Observation

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage]
    public private(set) var transcriptItems: [ChatTranscriptItem]
    public private(set) var isStreaming: Bool
    public private(set) var streamingText: String
    public private(set) var lastError: ChatErrorPresentation?
    public var lastErrorMessage: String? { lastError?.message }

    @ObservationIgnored
    private let chatService: (any ChatService)?

    @ObservationIgnored
    private let requirements: ExecutionRequirements

    public init(
        messages: [ChatMessage] = [],
        chatService: (any ChatService)? = nil,
        requirements: ExecutionRequirements = ExecutionRequirements(requiredCapabilities: [.chat])
    ) {
        self.messages = messages
        self.transcriptItems = messages.map(ChatTranscriptItem.message)
        self.chatService = chatService
        self.requirements = requirements
        self.isStreaming = false
        self.streamingText = ""
        self.lastError = nil
    }

    public func append(_ message: ChatMessage) {
        appendMessage(message)
    }

    public func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let userMessage = ChatMessage(role: .user, content: MessageContent(text: trimmed))
        appendMessage(userMessage)
        guard let chatService else {
            return
        }

        isStreaming = true
        streamingText = ""
        lastError = nil

        var accumulator = StreamedTextAccumulator()
        do {
            let request = ChatRequest(messages: messages, requirements: requirements)
            for try await event in chatService.send(request) {
                switch event {
                case .delta(let text):
                    accumulator.append(text)
                    streamingText = accumulator.text
                case .completed(let result):
                    appendMessage(result.message)
                    streamingText = ""
                case .failed(let error):
                    throw error
                case .toolCallRequested(let invocation):
                    upsertToolCall(invocation)
                case .toolCallCompleted(let result):
                    completeToolCall(result)
                case .started:
                    break
                }
            }

            if !accumulator.isEmpty, messages.last?.role != .assistant {
                appendMessage(ChatMessage(role: .assistant, content: MessageContent(text: accumulator.text)))
            }
        } catch {
            lastError = ChatErrorPresentation(error: error)
        }

        streamingText = ""
        isStreaming = false
    }

    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        transcriptItems.append(.message(message))
    }

    private func upsertToolCall(_ invocation: ToolInvocation) {
        let presentation = ToolCallPresentation(
            id: invocation.id,
            toolName: invocation.toolName,
            arguments: invocation.arguments,
            status: .running
        )

        if let index = transcriptItems.firstIndex(where: { $0.toolCallID == invocation.id }) {
            transcriptItems[index] = .tool(presentation)
        } else {
            transcriptItems.append(.tool(presentation))
        }
    }

    private func completeToolCall(_ result: ToolResult) {
        guard let index = transcriptItems.firstIndex(where: { $0.toolCallID == result.invocationID }) else {
            transcriptItems.append(.tool(ToolCallPresentation(
                id: result.invocationID,
                toolName: "Tool",
                arguments: ToolArguments(),
                status: result.isError ? .failed(result.content) : .completed(result.content)
            )))
            return
        }

        guard case .tool(let existing) = transcriptItems[index].content else {
            return
        }

        transcriptItems[index] = .tool(ToolCallPresentation(
            id: existing.id,
            toolName: existing.toolName,
            arguments: existing.arguments,
            status: result.isError ? .failed(result.content) : .completed(result.content)
        ))
    }
}

private struct StreamedTextAccumulator {
    private(set) var text = ""

    var isEmpty: Bool {
        text.isEmpty
    }

    mutating func append(_ delta: String) {
        text.append(delta)
    }
}
