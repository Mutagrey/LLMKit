import LLMCore

struct LlamaCppPromptFormatter: Sendable {
    func prompt(from messages: [ChatMessage]) throws -> String {
        guard !messages.isEmpty else {
            throw LLMError.executionFailed("llama.cpp chat requires at least one message.")
        }

        return messages
            .map(format(_:))
            .joined()
            + "<|start_header_id|>assistant<|end_header_id|>\n\n"
    }

    private func format(_ message: ChatMessage) -> String {
        let role = mappedRole(for: message.role)
        return "<|start_header_id|>\(role)<|end_header_id|>\n\n\(message.content.text)<|eot_id|>"
    }

    private func mappedRole(for role: MessageRole) -> String {
        switch role {
        case .system:
            "system"
        case .developer:
            "system"
        case .user:
            "user"
        case .assistant:
            "assistant"
        case .tool:
            "ipython"
        }
    }
}
