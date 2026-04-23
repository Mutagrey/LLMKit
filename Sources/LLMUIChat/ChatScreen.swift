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
            Divider()
            transcript
            Divider()
            composer
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if viewModel.isStreaming {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Streaming")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.messages) { message in
                    MessageBubble(message: message)
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
            .padding()
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draftText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            Button {
                let text = draftText
                draftText = ""
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
            .accessibilityLabel("Send")
        }
        .padding()
    }
}

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage]
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
        self.chatService = chatService
        self.requirements = requirements
        self.isStreaming = false
        self.streamingText = ""
        self.lastErrorMessage = nil
    }

    public func append(_ message: ChatMessage) {
        messages.append(message)
    }

    public func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let userMessage = ChatMessage(role: .user, content: MessageContent(text: trimmed))
        messages.append(userMessage)
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
                    messages.append(result.message)
                    streamingText = ""
                case .failed(let error):
                    throw error
                case .started, .toolCallRequested, .toolCallCompleted:
                    break
                }
            }
            if !accumulator.isEmpty, messages.last?.role != .assistant {
                messages.append(ChatMessage(role: .assistant, content: MessageContent(text: accumulator.text)))
            }
        } catch {
            lastErrorMessage = String(describing: error)
        }
        streamingText = ""
        isStreaming = false
    }
}

public struct ChatTheme: Hashable, Sendable {
    public init() {}
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.content.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            if message.role != .user {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var backgroundStyle: AnyShapeStyle {
        message.role == .user ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.gray.opacity(0.12))
    }
}

public enum LLMUIChatNamespace {}
