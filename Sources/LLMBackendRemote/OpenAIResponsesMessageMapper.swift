import Foundation
import LLMCore

struct OpenAIResponsesMessageMapping {
    let items: [OpenAIResponsesInputItem]
    let instructions: String?
}

enum OpenAIResponsesMessageMapper {
    static func map(_ messages: [ChatMessage]) throws -> OpenAIResponsesMessageMapping {
        var inputItems: [OpenAIResponsesInputItem] = []
        var instructionParts: [String] = []

        for message in messages {
            switch message.role {
            case .system, .developer:
                instructionParts.append(message.content.text)
            case .user, .assistant:
                inputItems.append(.message(role: message.role.rawValue, content: message.content.text))
            case .tool:
                guard let reference = message.toolCallReference else {
                    throw BackendError.mappingFailed("OpenAI Responses tool messages require a tool call reference.")
                }
                inputItems.append(.functionCallOutput(callID: reference.id.rawValue, output: message.content.text))
            }
        }

        return OpenAIResponsesMessageMapping(
            items: inputItems,
            instructions: instructionParts.isEmpty ? nil : instructionParts.joined(separator: "\n\n")
        )
    }
}
