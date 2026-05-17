import LLMCore
import MLXLMCommon

struct MLXChatPrompt {
    let history: [Chat.Message]
    let prompt: Chat.Message
}

struct MLXChatMessageMapper {
    func prompt(from messages: [ChatMessage]) throws -> MLXChatPrompt {
        var mapped = map(messages)
        guard let prompt = mapped.popLast() else {
            throw LLMError.executionFailed("MLX chat requires at least one message.")
        }
        return MLXChatPrompt(history: mapped, prompt: prompt)
    }

    func map(_ messages: [ChatMessage]) -> [Chat.Message] {
        messages.map(map(_:))
    }

    func map(_ message: ChatMessage) -> Chat.Message {
        switch message.role {
        case .system:
            return .system(message.content.text)
        case .developer:
            return .system("Developer: \(message.content.text)")
        case .user:
            return .user(message.content.text)
        case .assistant:
            return .assistant(message.content.text)
        case .tool:
            return .tool(message.content.text)
        }
    }
}
