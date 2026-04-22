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

    public init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    public func append(_ message: ChatMessage) {
        messages.append(message)
    }
}

public struct ChatTheme: Hashable, Sendable {
    public init() {}
}

public enum LLMUIChatNamespace {}
