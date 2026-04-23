import Foundation
import LLMCore

struct OpenAIResponsesMessageMapping {
    let messages: [OpenAIResponsesMessage]
    let instructions: String?
}

enum OpenAIResponsesMessageMapper {
    static func map(_ messages: [ChatMessage]) throws -> OpenAIResponsesMessageMapping {
        var inputMessages: [OpenAIResponsesMessage] = []
        var instructionParts: [String] = []

        for message in messages {
            switch message.role {
            case .system, .developer:
                instructionParts.append(message.content.text)
            case .user, .assistant:
                inputMessages.append(OpenAIResponsesMessage(role: message.role.rawValue, content: message.content.text))
            case .tool:
                throw BackendError.mappingFailed("OpenAI Responses mapping does not support tool role messages yet.")
            }
        }

        return OpenAIResponsesMessageMapping(
            messages: inputMessages,
            instructions: instructionParts.isEmpty ? nil : instructionParts.joined(separator: "\n\n")
        )
    }
}
