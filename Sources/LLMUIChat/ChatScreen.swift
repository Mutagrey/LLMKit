import LLMCore
import LLMProtocols
import SwiftUI

public struct ChatScreen: View {
    private let title: String

    public init(title: String = "Chat") {
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text("LLMKit chat UI scaffold").font(.subheadline)
        }
        .padding()
    }
}

@MainActor
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage]
    public private(set) var isStreaming: Bool
    public private(set) var lastErrorMessage: String?
    private let chatService: (any ChatService)?
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
        self.lastErrorMessage = nil
    }

    public func append(_ message: ChatMessage) {
        messages.append(message)
    }

    public func send(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: MessageContent(text: text))
        messages.append(userMessage)
        guard let chatService else {
            return
        }

        isStreaming = true
        lastErrorMessage = nil
        var accumulator = StreamedTextAccumulator()
        do {
            let request = ChatRequest(messages: messages, requirements: requirements)
            for try await event in chatService.send(request) {
                switch event {
                case .delta(let text):
                    accumulator.append(text)
                case .completed(let result):
                    messages.append(result.message)
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
        isStreaming = false
    }
}

public struct ChatTheme: Hashable, Sendable {
    public init() {}
}

public enum LLMUIChatNamespace {}
