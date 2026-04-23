import LLMCore
import LLMProtocols
import Observation
import SwiftUI

public struct ChatScreen: View {
    private let title: String
    @State private var viewModel: ChatViewModel
    @State private var draftText: String

    public init(
        title: String = "Chat",
        viewModel: ChatViewModel = ChatViewModel(),
        draftText: String = ""
    ) {
        self.title = title
        self._viewModel = State(initialValue: viewModel)
        self._draftText = State(initialValue: draftText)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            transcript
            composer
        }
        .background(Color.primary.opacity(0.03))
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(viewModel.isStreaming ? "Generating response" : "Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Streaming")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))
            Divider()
        }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.transcriptItems) { item in
                    switch item.content {
                    case .message(let message):
                        MessageBubble(message: message)
                    case .tool(let toolCall):
                        ToolActivityCard(toolCall: toolCall)
                    }
                }
                if !viewModel.streamingText.isEmpty {
                    MessageBubble(
                        message: ChatMessage(
                            role: .assistant,
                            content: MessageContent(text: viewModel.streamingText)
                        )
                    )
                }
                if let lastErrorMessage = viewModel.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message", text: $draftText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    let text = draftText
                    draftText = ""
                    Task { await viewModel.send(text) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))
        }
    }
}

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage]
    public private(set) var transcriptItems: [ChatTranscriptItem]
    public private(set) var isStreaming: Bool
    public private(set) var streamingText: String
    public private(set) var lastErrorMessage: String?
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
        self.lastErrorMessage = nil
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
        lastErrorMessage = nil
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
            lastErrorMessage = String(describing: error)
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

public struct ChatTheme: Hashable, Sendable {
    public init() {}
}

public struct ChatTranscriptItem: Identifiable, Hashable, Sendable {
    public enum Content: Hashable, Sendable {
        case message(ChatMessage)
        case tool(ToolCallPresentation)
    }

    public let id: String
    public let content: Content

    public static func message(_ message: ChatMessage) -> ChatTranscriptItem {
        ChatTranscriptItem(id: "message:\(message.id.uuidString)", content: .message(message))
    }

    public static func tool(_ toolCall: ToolCallPresentation) -> ChatTranscriptItem {
        ChatTranscriptItem(id: "tool:\(toolCall.id.rawValue)", content: .tool(toolCall))
    }

    fileprivate var toolCallID: ToolCallID? {
        guard case .tool(let toolCall) = content else {
            return nil
        }
        return toolCall.id
    }
}

public struct ToolCallPresentation: Identifiable, Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case running
        case completed(String)
        case failed(String)
    }

    public let id: ToolCallID
    public let toolName: String
    public let arguments: ToolArguments
    public let status: Status

    public init(id: ToolCallID, toolName: String, arguments: ToolArguments, status: Status) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.status = status
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 36)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.content.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if message.role != .user {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var backgroundStyle: AnyShapeStyle {
        message.role == .user
            ? AnyShapeStyle(.tint.opacity(0.14))
            : AnyShapeStyle(Color.primary.opacity(0.06))
    }
}

private struct ToolActivityCard: View {
    let toolCall: ToolCallPresentation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(iconColor)
                    Text(toolCall.toolName)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(statusLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !toolCall.arguments.structuredValues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(argumentLines, id: \.self) { line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let resultLine {
                    Text(resultLine)
                        .font(.footnote)
                        .foregroundStyle(resultColor)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLabel: String {
        switch toolCall.status {
        case .running:
            return "Running"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private var iconName: String {
        switch toolCall.status {
        case .running:
            return "hammer"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch toolCall.status {
        case .running:
            return .secondary
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var resultColor: Color {
        switch toolCall.status {
        case .running, .completed:
            return .primary
        case .failed:
            return .red
        }
    }

    private var argumentLines: [String] {
        toolCall.arguments.structuredValues
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.stringValue)" }
    }

    private var resultLine: String? {
        switch toolCall.status {
        case .running:
            return nil
        case .completed(let value), .failed(let value):
            return value
        }
    }
}

public enum LLMUIChatNamespace {}
