import Foundation
import LLMCore

struct FoundationModelsMappedChatPrompt: Sendable, Equatable {
    let instructions: String?
    let prompt: String
}

enum FoundationModelsPromptMapper {
    static func prompt(for request: ChatRequest) -> FoundationModelsMappedChatPrompt {
        var instructionLines: [String] = []
        var promptLines: [String] = []

        for message in request.messages {
            let text = message.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }

            switch message.role {
            case .system:
                instructionLines.append(text)
            case .developer:
                instructionLines.append("Developer: \(text)")
            case .user:
                promptLines.append("User: \(text)")
            case .assistant:
                promptLines.append("Assistant: \(text)")
            case .tool:
                promptLines.append("Tool: \(text)")
            }
        }

        return FoundationModelsMappedChatPrompt(
            instructions: instructionLines.isEmpty ? nil : instructionLines.joined(separator: "\n\n"),
            prompt: promptLines.isEmpty ? "" : promptLines.joined(separator: "\n\n")
        )
    }
}
