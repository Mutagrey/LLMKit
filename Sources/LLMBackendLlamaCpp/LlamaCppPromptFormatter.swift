import LLMCore

struct LlamaCppPromptFormatter: Sendable {
    func prompt(from messages: [ChatMessage], model: ModelDescriptor? = nil) throws -> String {
        guard !messages.isEmpty else {
            throw LLMError.executionFailed("llama.cpp chat requires at least one message.")
        }

        switch model?.family {
        case .qwen:
            return qwenPrompt(from: messages)
        case .gemma:
            if isGemma4(model) {
                return gemma4Prompt(from: messages)
            }
            return gemma3Prompt(from: messages)
        case .appleFoundation, .llama, .mistral, .custom, nil:
            return llamaPrompt(from: messages)
        }
    }

    private func llamaPrompt(from messages: [ChatMessage]) -> String {
        return messages
            .map(formatLlama(_:))
            .joined()
            + "<|start_header_id|>assistant<|end_header_id|>\n\n"
    }

    private func formatLlama(_ message: ChatMessage) -> String {
        let role = mappedRole(for: message.role)
        return "<|start_header_id|>\(role)<|end_header_id|>\n\n\(message.content.text)<|eot_id|>"
    }

    private func qwenPrompt(from messages: [ChatMessage]) -> String {
        messages
            .map { message in
                let role = mappedQwenRole(for: message.role)
                return "<|im_start|>\(role)\n\(message.content.text)<|im_end|>\n"
            }
            .joined()
            + "<|im_start|>assistant\n"
    }

    private func gemma3Prompt(from messages: [ChatMessage]) -> String {
        let systemText = messages
            .filter { $0.role == .system || $0.role == .developer }
            .map(\.content.text)
            .joined(separator: "\n\n")
        var didInjectSystem = false

        let turns = messages.compactMap { message -> String? in
            switch message.role {
            case .system, .developer:
                return nil
            case .user, .tool:
                let text: String
                if !didInjectSystem, !systemText.isEmpty {
                    didInjectSystem = true
                    text = "\(systemText)\n\n\(message.content.text)"
                } else {
                    text = message.content.text
                }
                return "<start_of_turn>user\n\(text)<end_of_turn>\n"
            case .assistant:
                return "<start_of_turn>model\n\(message.content.text)<end_of_turn>\n"
            }
        }

        if turns.isEmpty, !systemText.isEmpty {
            return "<start_of_turn>user\n\(systemText)<end_of_turn>\n<start_of_turn>model\n"
        }
        return turns.joined() + "<start_of_turn>model\n"
    }

    private func gemma4Prompt(from messages: [ChatMessage]) -> String {
        let turns = messages
            .map { message in
                let role = mappedGemma4Role(for: message.role)
                return "<|turn>\(role)\n\(message.content.text)<turn|>\n"
            }
            .joined()
        return "<bos>" + turns + "<|turn>model\n"
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

    private func mappedQwenRole(for role: MessageRole) -> String {
        switch role {
        case .system, .developer:
            "system"
        case .user:
            "user"
        case .assistant:
            "assistant"
        case .tool:
            "tool"
        }
    }

    private func mappedGemma4Role(for role: MessageRole) -> String {
        switch role {
        case .system, .developer:
            "system"
        case .user, .tool:
            "user"
        case .assistant:
            "model"
        }
    }

    private func isGemma4(_ model: ModelDescriptor?) -> Bool {
        guard let model else {
            return false
        }
        let id = model.id.rawValue.lowercased()
        return model.tags.contains("gemma4") || id.contains("gemma-4") || id.contains("gemma_4")
    }
}
